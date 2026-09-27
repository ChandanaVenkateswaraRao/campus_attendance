const fs = require('fs');
let code = fs.readFileSync('index.js', 'utf8');

const topImports = `
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
`;

const newRoutes = `

// --- Auth Routes ---
app.post('/api/register', (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Email and password required' });
  
  db.run('INSERT INTO wardens (email, password) VALUES (?, ?)', [email, password], function(err) {
    if (err) return res.status(400).json({ error: 'User already exists or error occurred' });
    const token = jwt.sign({ email }, JWT_SECRET);
    res.json({ token, email });
  });
});

app.post('/api/login', (req, res) => {
  const { email, password } = req.body;
  db.get('SELECT * FROM wardens WHERE email = ? AND password = ?', [email, password], (err, row) => {
    if (err || !row) return res.status(401).json({ error: 'Invalid credentials' });
    const token = jwt.sign({ email }, JWT_SECRET);
    res.json({ token, email });
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
`;

code = code.replace("const app = express();", topImports + "\nconst app = express();");
code = code.replace("// Sync Endpoint", newRoutes + "\n// Sync Endpoint");

fs.writeFileSync('index.js', code);
