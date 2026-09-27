const express = require('express');
const cors = require('cors');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');


const jwt = require('jsonwebtoken');
const JWT_SECRET = 'super-secret-key-for-wardens';

// Middleware to verify JWT
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (token == null) return res.sendStatus(401);
  
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    req.user = user;
    next();
  });
}

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));

// Setup SQLite Database
const dbPath = path.join(__dirname, 'database.sqlite');
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Error opening database', err.message);
  } else {
    console.log('Connected to the SQLite database.');
    
    // Create tables if they don't exist
    db.serialize(() => {
      // Wardens table for auth
      db.run(`
        CREATE TABLE IF NOT EXISTS wardens (
          email TEXT PRIMARY KEY,
          password TEXT,
          name TEXT,
          hostel_name TEXT,
          block_name TEXT,
          floor_number TEXT
        )
      `);
      
      // Cloud backup tables keyed by warden_email
      db.run(`
        CREATE TABLE IF NOT EXISTS cloud_rooms (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          warden_email TEXT,
          local_id INTEGER,
          name TEXT
        )
      `);

      db.run(`
        CREATE TABLE IF NOT EXISTS cloud_students (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          warden_email TEXT,
          local_id INTEGER,
          name TEXT,
          studentId TEXT,
          room_local_id INTEGER
        )
      `);

      db.run(`
        CREATE TABLE IF NOT EXISTS cloud_face_embeddings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          warden_email TEXT,
          local_id INTEGER,
          vector_json TEXT,
          student_local_id INTEGER
        )
      `);

      // We will store synced attendance records here
      db.run(`
        CREATE TABLE IF NOT EXISTS attendance_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          local_record_id INTEGER,
          room_name TEXT,
          timestamp TEXT,
          present_students_json TEXT
        )
      `);
    });
  }
});



// --- Auth Routes ---
app.post('/api/register', (req, res) => {
  const { email, password, name, hostel_name, block_name, floor_number } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Email and password required' });
  
  db.run('ALTER TABLE wardens ADD COLUMN name TEXT', () => {});
  db.run('ALTER TABLE wardens ADD COLUMN hostel_name TEXT', () => {});
  db.run('ALTER TABLE wardens ADD COLUMN block_name TEXT', () => {});
  db.run('ALTER TABLE wardens ADD COLUMN floor_number TEXT', () => {
    db.run('INSERT INTO wardens (email, password, name, hostel_name, block_name, floor_number) VALUES (?, ?, ?, ?, ?, ?)', 
      [email, password, name, hostel_name, block_name, floor_number], function(err) {
      if (err) return res.status(400).json({ error: 'User already exists or error occurred' });
      const token = jwt.sign({ email }, JWT_SECRET);
      res.json({ token, email, name, hostel_name, block_name, floor_number });
    });
  });
});

app.post('/api/login', (req, res) => {
  const { email, password } = req.body;
  db.get('SELECT * FROM wardens WHERE email = ? AND password = ?', [email, password], (err, row) => {
    if (err || !row) return res.status(401).json({ error: 'Invalid credentials' });
    const token = jwt.sign({ email }, JWT_SECRET);
    res.json({ 
      token, 
      email: row.email, 
      name: row.name, 
      hostel_name: row.hostel_name, 
      block_name: row.block_name, 
      floor_number: row.floor_number 
    });
  });
});

// --- Backup & Restore Routes ---
app.post('/api/backup', authenticateToken, (req, res) => {
  const email = req.user.email;
  const { rooms, students, faceEmbeddings } = req.body;

  db.serialize(() => {
    db.run('BEGIN TRANSACTION');
    
    // Clear old backup for this warden
    db.run('DELETE FROM cloud_rooms WHERE warden_email = ?', [email]);
    db.run('DELETE FROM cloud_students WHERE warden_email = ?', [email]);
    db.run('DELETE FROM cloud_face_embeddings WHERE warden_email = ?', [email]);
    
    // Insert rooms
    const insertRoom = db.prepare('INSERT INTO cloud_rooms (warden_email, local_id, name) VALUES (?, ?, ?)');
    (rooms || []).forEach(r => insertRoom.run([email, r.id, r.name]));
    insertRoom.finalize();
    
    // Insert students
    const insertStudent = db.prepare('INSERT INTO cloud_students (warden_email, local_id, name, studentId, room_local_id) VALUES (?, ?, ?, ?, ?)');
    (students || []).forEach(s => insertStudent.run([email, s.id, s.name, s.studentId, s.room_local_id || s.room.value?.id]));
    insertStudent.finalize();
    
    // Insert embeddings
    const insertEmb = db.prepare('INSERT INTO cloud_face_embeddings (warden_email, local_id, vector_json, student_local_id) VALUES (?, ?, ?, ?)');
    (faceEmbeddings || []).forEach(f => insertEmb.run([email, f.id, JSON.stringify(f.vector), f.student_local_id || f.student.value?.id]));
    insertEmb.finalize();
    
    db.run('COMMIT', (err) => {
      if (err) res.status(500).json({ error: 'Backup failed' });
      else res.json({ message: 'Backup successful' });
    });
  });
});

app.get('/api/restore', authenticateToken, (req, res) => {
  const email = req.user.email;
  
  const result = { rooms: [], students: [], faceEmbeddings: [] };
  
  db.serialize(() => {
    db.all('SELECT * FROM cloud_rooms WHERE warden_email = ?', [email], (err, rows) => {
      if (!err) result.rooms = rows;
    });
    db.all('SELECT * FROM cloud_students WHERE warden_email = ?', [email], (err, rows) => {
      if (!err) result.students = rows;
    });
    db.all('SELECT * FROM cloud_face_embeddings WHERE warden_email = ?', [email], (err, rows) => {
      if (!err) result.faceEmbeddings = rows.map(r => ({...r, vector: JSON.parse(r.vector_json)}));
    });
  });
  
  // Quick hack to wait for queries
  setTimeout(() => {
    res.json(result);
  }, 200);
});

// Sync Endpoint
app.post('/api/sync', (req, res) => {
  const records = req.body.records;
  
  if (!records || !Array.isArray(records)) {
    return res.status(400).json({ error: 'Invalid payload format. Expected an array of records.' });
  }

  console.log(`Received ${records.length} records for syncing.`);
  
  const insertStmt = db.prepare(`
    INSERT INTO attendance_records (local_record_id, room_name, timestamp, present_students_json)
    VALUES (?, ?, ?, ?)
  `);

  db.serialize(() => {
    db.run('BEGIN TRANSACTION');
    
    records.forEach(record => {
      // Present students might be sent as a list of objects or names
      const studentsJson = JSON.stringify(record.presentStudents || []);
      
      insertStmt.run([
        record.id,
        record.roomName,
        record.timestamp,
        studentsJson
      ]);
    });

    db.run('COMMIT', (err) => {
      if (err) {
        console.error('Error committing transaction', err);
        res.status(500).json({ error: 'Failed to save synced data' });
      } else {
        console.log('Successfully saved synced data.');
        res.status(200).json({ message: 'Sync successful', count: records.length });
      }
    });
  });
  
  insertStmt.finalize();
});

// View Endpoint for testing
app.get('/api/records', (req, res) => {
  db.all('SELECT * FROM attendance_records ORDER BY id DESC', [], (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
    // Parse the JSON string back into an object for the response
    const formattedRows = rows.map(row => ({
      ...row,
      present_students: JSON.parse(row.present_students_json)
    }));
    
    res.json(formattedRows);
  });
});

// Update Endpoint for online editing
app.put('/api/attendance/:id', authenticateToken, (req, res) => {
  const recordId = req.params.id;
  const { present_students } = req.body;
  
  if (!present_students || !Array.isArray(present_students)) {
    return res.status(400).json({ error: 'present_students must be an array' });
  }

  const studentsJson = JSON.stringify(present_students);

  db.run(
    'UPDATE attendance_records SET present_students_json = ? WHERE id = ?',
    [studentsJson, recordId],
    function(err) {
      if (err) {
        console.error('Error updating record', err);
        return res.status(500).json({ error: 'Failed to update record' });
      }
      if (this.changes === 0) {
        return res.status(404).json({ error: 'Record not found' });
      }
      res.json({ message: 'Record updated successfully' });
    }
  );
});

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
