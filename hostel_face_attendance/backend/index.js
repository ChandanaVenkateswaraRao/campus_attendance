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

      db.run(`
        CREATE TABLE IF NOT EXISTS hostel_admins (
          email TEXT PRIMARY KEY,
          password TEXT,
          hostel_name TEXT
        )
      `);

      // Leaves and Outings tables
      db.run(`
        CREATE TABLE IF NOT EXISTS leaves (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_email TEXT,
          from_date TEXT,
          to_date TEXT,
          status TEXT DEFAULT 'PENDING',
          reason TEXT
        )
      `);
      db.run(`
        CREATE TABLE IF NOT EXISTS outings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_email TEXT,
          date TEXT,
          start_time TEXT,
          end_time TEXT,
          status TEXT DEFAULT 'PENDING',
          reason TEXT
        )
      `);

      db.run('ALTER TABLE cloud_students ADD COLUMN phone_number TEXT', () => {});
      db.run('ALTER TABLE cloud_students ADD COLUMN father_phone_number TEXT', () => {});
      db.run('ALTER TABLE cloud_students ADD COLUMN mother_phone_number TEXT', () => {});
      db.run('ALTER TABLE cloud_students ADD COLUMN email TEXT', () => {});
      
      // Ensure reason columns exist on existing DBs
      db.run('ALTER TABLE leaves ADD COLUMN reason TEXT', () => {});
      db.run('ALTER TABLE outings ADD COLUMN reason TEXT', () => {});
    });
  }
});

// --- Student Portal Routes ---
app.post('/api/student/login', (req, res) => {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'Email required' });
  
  db.get('SELECT * FROM cloud_students WHERE email = ?', [email], (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    
    if (!row) {
      // Auto-register for testing purposes if not found
      const mockName = email.split('@')[0];
      const mockId = Math.floor(Math.random() * 100000).toString();
      
      db.run('INSERT INTO cloud_students (name, studentId, email, warden_email) VALUES (?, ?, ?, ?)', 
        [mockName, mockId, email, 'warden@example.com'], 
        function(insertErr) {
          if (insertErr) return res.status(500).json({ error: insertErr.message });
          
          const newStudent = { email, name: mockName, studentId: mockId };
          const token = jwt.sign({ email, role: 'student', studentId: mockId, name: mockName }, JWT_SECRET);
          return res.json({ token, student: newStudent });
      });
      return;
    }
    
    // Create a student token
    const token = jwt.sign({ email, role: 'student', studentId: row.studentId, name: row.name }, JWT_SECRET);
    res.json({ token, student: row });
  });
});

app.post('/api/student/leave', authenticateToken, (req, res) => {
  if (req.user.role !== 'student') return res.status(403).json({ error: 'Forbidden' });
  const { from_date, to_date, reason } = req.body;
  db.run('INSERT INTO leaves (student_email, from_date, to_date, reason) VALUES (?, ?, ?, ?)', 
    [req.user.email, from_date, to_date, reason || ''], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ success: true, message: 'Leave applied successfully' });
  });
});

app.get('/api/student/leaves', authenticateToken, (req, res) => {
  if (req.user.role !== 'student') return res.status(403).json({ error: 'Forbidden' });
  db.all('SELECT * FROM leaves WHERE student_email = ? ORDER BY id DESC', [req.user.email], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.post('/api/student/outing', authenticateToken, (req, res) => {
  if (req.user.role !== 'student') return res.status(403).json({ error: 'Forbidden' });
  const { date, start_time, end_time, reason } = req.body;
  db.run('INSERT INTO outings (student_email, date, start_time, end_time, reason) VALUES (?, ?, ?, ?, ?)', 
    [req.user.email, date, start_time, end_time, reason || ''], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ success: true, message: 'Outing applied successfully' });
  });
});

app.get('/api/student/outings', authenticateToken, (req, res) => {
  if (req.user.role !== 'student') return res.status(403).json({ error: 'Forbidden' });
  db.all('SELECT * FROM outings WHERE student_email = ? ORDER BY id DESC', [req.user.email], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.get('/api/student/attendance', authenticateToken, (req, res) => {
  if (req.user.role !== 'student') return res.status(403).json({ error: 'Forbidden' });
  
  db.all('SELECT * FROM attendance_records ORDER BY timestamp DESC', [], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    
    // Map dates to attendance status
    const dateMap = {};
    
    rows.forEach(row => {
      const dateStr = row.timestamp.split('T')[0]; // Extract YYYY-MM-DD
      const present = JSON.parse(row.present_students_json || '[]');
      const isPresent = present.some(p => p.studentId === req.user.studentId || p.name === req.user.name);
      
      if (!dateMap[dateStr]) {
        dateMap[dateStr] = { date: row.timestamp, status: isPresent ? 'Present' : 'Absent' };
      } else if (isPresent) {
        // If marked present in any record for this day, count as present
        dateMap[dateStr].status = 'Present';
      }
    });
    
    const attendanceList = Object.values(dateMap).sort((a, b) => b.date.localeCompare(a.date));
    res.json({ attendanceList });
  });
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
    const insertStudent = db.prepare('INSERT INTO cloud_students (warden_email, local_id, name, studentId, room_local_id, phone_number, father_phone_number, mother_phone_number, email) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)');
    (students || []).forEach(s => insertStudent.run([email, s.id, s.name, s.studentId, s.room_local_id || s.room.value?.id, s.phoneNumber, s.fatherPhoneNumber, s.motherPhoneNumber, s.email]));
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
      if (!err) result.students = rows.map(r => ({
        ...r,
        phoneNumber: r.phone_number,
        fatherPhoneNumber: r.father_phone_number,
        motherPhoneNumber: r.mother_phone_number,
        email: r.email
      }));
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

// Admin Endpoints
app.get('/api/admin/wardens', (req, res) => {
  db.all('SELECT email, name, hostel_name, block_name, floor_number FROM wardens', [], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.put('/api/admin/wardens/:email', (req, res) => {
  const email = req.params.email;
  const { name, password, hostel_name, block_name, floor_number } = req.body;
  
  if (password && password.trim() !== '') {
    const sql = 'UPDATE wardens SET name = ?, password = ?, hostel_name = ?, block_name = ?, floor_number = ? WHERE email = ?';
    db.run(sql, [name, password, hostel_name, block_name, floor_number, email], function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ success: true, message: 'Warden updated successfully with new password.' });
    });
  } else {
    const sql = 'UPDATE wardens SET name = ?, hostel_name = ?, block_name = ?, floor_number = ? WHERE email = ?';
    db.run(sql, [name, hostel_name, block_name, floor_number, email], function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ success: true, message: 'Warden updated successfully.' });
    });
  }
});

app.put('/api/admin/students/:db_id', (req, res) => {
  const db_id = req.params.db_id;
  const { name, studentId, phone_number, email, father_phone_number, mother_phone_number } = req.body;
  const sql = 'UPDATE cloud_students SET name=?, studentId=?, phone_number=?, email=?, father_phone_number=?, mother_phone_number=? WHERE id=?';
  db.run(sql, [name, studentId, phone_number, email, father_phone_number, mother_phone_number, db_id], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ success: true, message: 'Student updated successfully.' });
  });
});

app.delete('/api/admin/students/:db_id', (req, res) => {
  const db_id = req.params.db_id;
  db.run('DELETE FROM cloud_students WHERE id=?', [db_id], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ success: true, message: 'Student deleted successfully.' });
  });
});

app.post('/api/admin/attendance/toggle', (req, res) => {
  const { date, room_name, student } = req.body;
  const targetId = student.local_id || student.db_id;
  
  db.all('SELECT * FROM attendance_records WHERE timestamp LIKE ? AND room_name = ?', [date + '%', room_name], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    
    if (rows && rows.length > 0) {
      // Determine if they are currently present in ANY of the records
      let isCurrentlyPresent = false;
      rows.forEach(row => {
        let present = JSON.parse(row.present_students_json || '[]');
        if (present.some(p => p.id === targetId || p.id === student.db_id || p.id === student.local_id || p.studentId === student.studentId || p.name === student.name)) {
          isCurrentlyPresent = true;
        }
      });
      
      let updatePromises = [];
      
      rows.forEach(row => {
        let present = JSON.parse(row.present_students_json || '[]');
        if (isCurrentlyPresent) {
          // Remove from all
          present = present.filter(p => p.id !== targetId && p.id !== student.db_id && p.id !== student.local_id && p.studentId !== student.studentId && p.name !== student.name);
        } else {
          // Add to all
          present.push({ id: targetId, name: student.name, studentId: student.studentId });
        }
        
        updatePromises.push(new Promise((resolve, reject) => {
          db.run('UPDATE attendance_records SET present_students_json = ? WHERE id = ?', [JSON.stringify(present), row.id], function(updateErr) {
            if (updateErr) reject(updateErr);
            else resolve();
          });
        }));
      });
      
      Promise.all(updatePromises)
        .then(() => res.json({ success: true, present: !isCurrentlyPresent }))
        .catch(updateErr => res.status(500).json({ error: updateErr.message }));
        
    } else {
      const newTimestamp = `${date}T00:00:00.000Z`;
      const present = [{ id: targetId, name: student.name, studentId: student.studentId }];
      db.run('INSERT INTO attendance_records (room_name, timestamp, present_students_json) VALUES (?, ?, ?)', [room_name, newTimestamp, JSON.stringify(present)], function(insertErr) {
         if (insertErr) return res.status(500).json({ error: insertErr.message });
         res.json({ success: true, present: true });
      });
    }
  });
});

app.delete('/api/admin/wardens/:email', (req, res) => {
  const email = req.params.email;
  db.serialize(() => {
    db.run('BEGIN TRANSACTION');
    db.run('DELETE FROM wardens WHERE email = ?', [email]);
    db.run('DELETE FROM cloud_students WHERE warden_email = ?', [email]);
    db.run('DELETE FROM cloud_rooms WHERE warden_email = ?', [email]);
    db.run('DELETE FROM cloud_face_embeddings WHERE warden_email = ?', [email], function(err) {
      if (err) {
        db.run('ROLLBACK');
        return res.status(500).json({ error: err.message });
      }
      db.run('COMMIT');
      res.json({ success: true, message: 'Warden and associated data deleted.' });
    });
  });
});

app.get('/api/admin/detailed_students', (req, res) => {
  const query = `
    SELECT 
      s.id as db_id, s.local_id, s.name, s.studentId, s.room_local_id, s.warden_email,
      s.phone_number, s.father_phone_number, s.mother_phone_number, s.email,
      w.hostel_name, w.block_name, w.floor_number,
      r.name as room_name
    FROM cloud_students s
    LEFT JOIN wardens w ON s.warden_email = w.email
    LEFT JOIN cloud_rooms r ON s.room_local_id = r.local_id AND s.warden_email = r.warden_email
  `;
  db.all(query, [], (err, students) => {
    if (err) return res.status(500).json({ error: err.message });
    
    db.all('SELECT * FROM attendance_records ORDER BY timestamp DESC', [], (err, records) => {
       if (err) return res.status(500).json({ error: err.message });
       
       const formattedRecords = records.map(row => ({
         ...row,
         present_students: JSON.parse(row.present_students_json || '[]')
       }));
       
       res.json({ students, records: formattedRecords });
    });
  });
});

app.get('/api/admin/stats', (req, res) => {
  const stats = { wardens: 0, records: 0, students: 0 };
  
  db.get('SELECT COUNT(*) as count FROM wardens', (err, row) => {
    if (!err && row) stats.wardens = row.count;
    
    db.get('SELECT COUNT(*) as count FROM attendance_records', (err, row) => {
      if (!err && row) stats.records = row.count;
      
      db.get('SELECT COUNT(*) as count FROM cloud_students', (err, row) => {
        if (!err && row) stats.students = row.count;
        res.json(stats);
      });
    });
  });
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

// Fetch Attendance History Endpoint
app.get('/api/attendance', authenticateToken, (req, res) => {
  const { date } = req.query;
  let query = 'SELECT * FROM attendance_records';
  let params = [];

  if (date) {
    query += ' WHERE timestamp LIKE ?';
    params.push(`${date}%`);
  }

  query += ' ORDER BY timestamp DESC';

  db.all(query, params, (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    
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

// --- Leaves & Outings Management (Admin/Warden) ---
app.get('/api/admin/leaves', (req, res) => {
  const query = `
    SELECT 
      l.id, l.from_date, l.to_date, l.status, l.reason, l.student_email,
      s.name as student_name, s.studentId as register_number, 
      r.name as room_number,
      w.email as warden_email, w.hostel_name, w.block_name, w.floor_number
    FROM leaves l
    JOIN cloud_students s ON l.student_email = s.email
    LEFT JOIN wardens w ON s.warden_email = w.email
    LEFT JOIN cloud_rooms r ON s.room_local_id = r.local_id AND s.warden_email = r.warden_email
    ORDER BY l.id DESC
  `;
  db.all(query, [], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.put('/api/admin/leaves/:id/status', (req, res) => {
  const { status } = req.body;
  db.run('UPDATE leaves SET status = ? WHERE id = ?', [status, req.params.id], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ success: true });
  });
});

app.get('/api/admin/outings', (req, res) => {
  const query = `
    SELECT 
      o.id, o.date, o.start_time, o.end_time, o.status, o.reason, o.student_email,
      s.name as student_name, s.studentId as register_number, 
      r.name as room_number,
      w.email as warden_email, w.hostel_name, w.block_name, w.floor_number
    FROM outings o
    JOIN cloud_students s ON o.student_email = s.email
    LEFT JOIN wardens w ON s.warden_email = w.email
    LEFT JOIN cloud_rooms r ON s.room_local_id = r.local_id AND s.warden_email = r.warden_email
    ORDER BY o.id DESC
  `;
  db.all(query, [], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.put('/api/admin/outings/:id/status', (req, res) => {
  const { status } = req.body;
  db.run('UPDATE outings SET status = ? WHERE id = ?', [status, req.params.id], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ success: true });
  });
});

// --- Warden Specific Endpoints (for Mobile App) ---
app.get('/api/warden/leaves', authenticateToken, (req, res) => {
  const query = `
    SELECT 
      l.id, l.from_date, l.to_date, l.status, l.reason, l.student_email,
      s.name as student_name, s.studentId as register_number, 
      r.name as room_number
    FROM leaves l
    JOIN cloud_students s ON l.student_email = s.email
    LEFT JOIN cloud_rooms r ON s.room_local_id = r.local_id AND s.warden_email = r.warden_email
    WHERE s.warden_email = ?
    ORDER BY l.id DESC
  `;
  db.all(query, [req.user.email], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.put('/api/warden/leaves/:id/status', authenticateToken, (req, res) => {
  const { status } = req.body;
  db.run('UPDATE leaves SET status = ? WHERE id = ?', [status, req.params.id], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ success: true });
  });
});

app.get('/api/warden/outings', authenticateToken, (req, res) => {
  const query = `
    SELECT 
      o.id, o.date, o.start_time, o.end_time, o.status, o.reason, o.student_email,
      s.name as student_name, s.studentId as register_number, 
      r.name as room_number
    FROM outings o
    JOIN cloud_students s ON o.student_email = s.email
    LEFT JOIN cloud_rooms r ON s.room_local_id = r.local_id AND s.warden_email = r.warden_email
    WHERE s.warden_email = ?
    ORDER BY o.id DESC
  `;
  db.all(query, [req.user.email], (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.put('/api/warden/outings/:id/status', authenticateToken, (req, res) => {
  const { status } = req.body;
  db.run('UPDATE outings SET status = ? WHERE id = ?', [status, req.params.id], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ success: true });
  });
});

// --- Hostel Admins CRUD ---
app.get('/api/admin/hostel_admins', (req, res) => {
  db.all('SELECT email, hostel_name FROM hostel_admins', (err, rows) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(rows);
  });
});

app.post('/api/admin/hostel_admins', (req, res) => {
  const { email, password, hostel_name } = req.body;
  db.run('INSERT INTO hostel_admins (email, password, hostel_name) VALUES (?, ?, ?)', [email, password, hostel_name], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ success: true });
  });
});

app.put('/api/admin/hostel_admins/:email', (req, res) => {
  const { password, hostel_name } = req.body;
  const email = req.params.email;
  if (password) {
    db.run('UPDATE hostel_admins SET password=?, hostel_name=? WHERE email=?', [password, hostel_name, email], function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ success: true });
    });
  } else {
    db.run('UPDATE hostel_admins SET hostel_name=? WHERE email=?', [hostel_name, email], function(err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ success: true });
    });
  }
});

app.delete('/api/admin/hostel_admins/:email', (req, res) => {
  const email = req.params.email;
  db.run('DELETE FROM hostel_admins WHERE email=?', [email], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ success: true });
  });
});

// --- Login Route ---
app.post('/api/admin/login', (req, res) => {
  const { email, password } = req.body;
  if (email === 'admin@klu.ac.in' && password === 'admin@klu.ac.in') {
    return res.json({ success: true, role: 'super_admin', hostel_name: null });
  }

  db.get('SELECT * FROM hostel_admins WHERE email = ? AND password = ?', [email, password], (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    if (row) {
      return res.json({ success: true, role: 'hostel_admin', hostel_name: row.hostel_name, email: row.email });
    }
    return res.status(401).json({ error: 'Invalid email or password' });
  });
});

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
