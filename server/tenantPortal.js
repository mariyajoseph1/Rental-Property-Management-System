// Tenant login add-on: separate login for tenants, completely independent of the admin login.
// A tenant sees only their own lease(s) and payments.
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

module.exports = function tenantPortal(app, getDb, secret, wrap) {
  const TS = secret + ':tenant'; // different secret, so a tenant token never works on admin pages
  let ready;
  const ensure = () => (ready ||= getDb().query(`CREATE TABLE IF NOT EXISTS tenant_logins (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id INT NOT NULL UNIQUE,
    email VARCHAR(160) NOT NULL UNIQUE,
    password_hash VARCHAR(100) NOT NULL,
    FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE
  ) ENGINE=InnoDB`));
  const digits = (v) => String(v || '').replace(/\D/g, '');
  const sign = (t) => ({ token: jwt.sign({ tenantId: t.id, name: t.name }, TS, { expiresIn: '8h' }), name: t.name });
  const noMatch = 'We could not match these details to a tenant record. Check your email and phone number with your property manager.';

  // First time: tenant creates a password. Email AND phone must match the tenant record the admin entered.
  app.post('/api/tenant/register', wrap(async (q, s) => {
    await ensure(); const db = getDb();
    const { email, phone, password } = q.body || {};
    if (!email || !phone || !password) return s.status(400).json({ error: 'Email, phone and password are required' });
    if (password.length < 6) return s.status(400).json({ error: 'Password must be at least 6 characters' });
    const [rows] = await db.query('SELECT id, name, phone FROM tenants WHERE email=?', [email]);
    const t = rows[0];
    if (!t || digits(t.phone).length < 6 || digits(t.phone).slice(-10) !== digits(phone).slice(-10))
      return s.status(400).json({ error: noMatch });
    const [dup] = await db.query('SELECT id FROM tenant_logins WHERE tenant_id=?', [t.id]);
    if (dup.length) return s.status(409).json({ error: 'A login already exists for this tenant. Please sign in.' });
    await db.query('INSERT INTO tenant_logins(tenant_id,email,password_hash) VALUES(?,?,?)', [t.id, email, await bcrypt.hash(password, 10)]);
    s.status(201).json(sign(t));
  }));

  app.post('/api/tenant/login', wrap(async (q, s) => {
    await ensure(); const db = getDb();
    const { email, password } = q.body || {};
    const [rows] = await db.query(
      'SELECT l.password_hash, t.id, t.name FROM tenant_logins l JOIN tenants t ON t.id = l.tenant_id WHERE l.email=?', [email || '']);
    const r = rows[0];
    if (!r || !(await bcrypt.compare(password || '', r.password_hash))) return s.status(401).json({ error: 'Wrong email or password' });
    s.json(sign(r));
  }));

  app.get('/api/tenant/me', wrap(async (q, s) => {
    let me;
    try { me = jwt.verify((q.headers.authorization || '').replace('Bearer ', ''), TS); }
    catch { return s.status(401).json({ error: 'Please log in' }); }
    const db = getDb();
    const [t] = await db.query('SELECT id, name, email, phone FROM tenants WHERE id=?', [me.tenantId]);
    if (!t[0]) return s.status(401).json({ error: 'Please log in' });
    const [leases] = await db.query(
      `SELECT l.id, l.start_date, l.end_date, l.monthly_rent, p.name AS property, p.address, p.city
       FROM leases l JOIN properties p ON p.id = l.property_id WHERE l.tenant_id = ? ORDER BY l.start_date DESC`, [me.tenantId]);
    const [payments] = await db.query(
      `SELECT y.id, y.amount, y.paid_on, y.method, p.name AS property
       FROM payments y JOIN leases l ON l.id = y.lease_id JOIN properties p ON p.id = l.property_id
       WHERE l.tenant_id = ? ORDER BY y.paid_on DESC, y.id DESC`, [me.tenantId]);
    s.json({ tenant: t[0], leases, payments });
  }));
};
