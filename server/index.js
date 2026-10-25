require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');

const cfg = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
};
const DB = process.env.DB_NAME || 'rental_pms';
const SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';
let db;

async function initDb() {
  // create database + tables (schema.sql), then seed sample data once
  const boot = await mysql.createConnection({ ...cfg, multipleStatements: true });
  await boot.query(fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8').replace(/rental_pms/g, DB));
  await boot.end();
  db = mysql.createPool({ ...cfg, database: DB, dateStrings: true, multipleStatements: true });
  const [[{ c }]] = await db.query('SELECT COUNT(*) c FROM properties');
  if (!c) await db.query(fs.readFileSync(path.join(__dirname, 'seed.sql'), 'utf8'));
  // first admin login (set ADMIN_EMAIL / ADMIN_PASSWORD in server/.env before the first start)
  const [[{ u }]] = await db.query('SELECT COUNT(*) u FROM users');
  if (!u) {
    const email = process.env.ADMIN_EMAIL || 'admin@rental.com';
    const hash = await bcrypt.hash(process.env.ADMIN_PASSWORD || 'admin123', 10);
    await db.query('INSERT INTO users(name,email,password_hash) VALUES(?,?,?)', ['Administrator', email, hash]);
    console.log(`Created admin login: ${email}`);
  }
}

// table -> writable columns + list query (joined, so the UI can show names)
const R = {
  properties: { cols: ['name', 'address', 'city', 'rent', 'status'], sql: 'SELECT * FROM properties' },
  tenants: { cols: ['name', 'email', 'phone'], sql: 'SELECT * FROM tenants' },
  leases: {
    cols: ['property_id', 'tenant_id', 'start_date', 'end_date', 'monthly_rent'],
    sql: `SELECT l.*, p.name AS property, t.name AS tenant FROM leases l
          JOIN properties p ON p.id = l.property_id JOIN tenants t ON t.id = l.tenant_id`,
  },
  payments: {
    cols: ['lease_id', 'amount', 'paid_on', 'method'],
    sql: `SELECT y.*, t.name AS tenant, p.name AS property FROM payments y
          JOIN leases l ON l.id = y.lease_id JOIN tenants t ON t.id = l.tenant_id
          JOIN properties p ON p.id = l.property_id`,
  },
  maintenance: {
    cols: ['property_id', 'title', 'description', 'priority', 'status'],
    sql: 'SELECT m.*, p.name AS property FROM maintenance m JOIN properties p ON p.id = m.property_id',
  },
};

const app = express();
app.use(cors(), express.json());
const wrap = (fn) => (q, s) => fn(q, s).catch((e) => s.status(400).json({ error: e.sqlMessage || e.message }));

app.get('/api/health', wrap(async (_q, s) => {
  await db.query('SELECT 1');
  s.json({ api: 'ok', database: DB, connected: true });
}));

// admin (property manager) login
app.post('/api/auth/login', wrap(async (q, s) => {
  const { email, password } = q.body || {};
  const [rows] = await db.query('SELECT * FROM users WHERE email=?', [email || '']);
  const user = rows[0];
  if (!user || !(await bcrypt.compare(password || '', user.password_hash)))
    return s.status(401).json({ error: 'Wrong email or password' });
  s.json({ token: jwt.sign({ id: user.id, name: user.name }, SECRET, { expiresIn: '8h' }), name: user.name });
}));

// tenant login page (/tenant): separate login, tenants see only their own lease and payments
require('./tenantPortal')(app, () => db, SECRET, wrap);

// everything below this line needs a valid admin login token
app.use('/api', (q, s, next) => {
  const t = (q.headers.authorization || '').replace('Bearer ', '');
  try { q.user = jwt.verify(t, SECRET); next(); } catch { s.status(401).json({ error: 'Please log in' }); }
});

app.get('/api/stats', wrap(async (_q, s) => {
  const one = async (sql) => Number((await db.query(sql))[0][0].v);
  s.json({
    properties: await one('SELECT COUNT(*) v FROM properties'),
    occupied: await one("SELECT COUNT(*) v FROM properties WHERE status='occupied'"),
    tenants: await one('SELECT COUNT(*) v FROM tenants'),
    expectedRent: await one("SELECT COALESCE(SUM(rent),0) v FROM properties WHERE status='occupied'"),
    collectedThisMonth: await one("SELECT COALESCE(SUM(amount),0) v FROM payments WHERE DATE_FORMAT(paid_on,'%Y-%m')=DATE_FORMAT(CURDATE(),'%Y-%m')"),
    openRequests: await one("SELECT COUNT(*) v FROM maintenance WHERE status<>'done'"),
  });
}));

for (const [name, { cols, sql }] of Object.entries(R)) {
  const vals = (b) => cols.map((c) => (b[c] === '' || b[c] === undefined ? null : b[c]));
  app.get(`/api/${name}`, wrap(async (_q, s) => s.json((await db.query(`${sql} ORDER BY 1 DESC`))[0])));
  app.post(`/api/${name}`, wrap(async (q, s) => {
    const [r] = await db.query(`INSERT INTO ${name} (${cols.join(',')}) VALUES (${cols.map(() => '?').join(',')})`, vals(q.body));
    s.status(201).json({ id: r.insertId });
  }));
  app.put(`/api/${name}/:id`, wrap(async (q, s) => {
    await db.query(`UPDATE ${name} SET ${cols.map((c) => c + '=?').join(',')} WHERE id=?`, [...vals(q.body), q.params.id]);
    s.json({ ok: true });
  }));
  app.delete(`/api/${name}/:id`, wrap(async (q, s) => {
    await db.query(`DELETE FROM ${name} WHERE id=?`, [q.params.id]);
    s.json({ ok: true });
  }));
}

// the website: one single page (server/public/index.html) for the admin site and the tenant page
app.use(express.static(path.join(__dirname, 'public')));
app.get(/^(?!\/api).*/, (_q, s) => s.sendFile(path.join(__dirname, 'public', 'index.html')));

initDb()
  .then(() => app.listen(process.env.PORT || 4000, () => console.log(`API running on http://localhost:${process.env.PORT || 4000}`)))
  .catch((e) => { console.error('Database connection failed:', e.message, '\nCheck DB_USER / DB_PASSWORD in server/.env and that MySQL is running.'); process.exit(1); });
