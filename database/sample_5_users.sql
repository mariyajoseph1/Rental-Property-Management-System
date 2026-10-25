-- 5 sample tenants with logins. Safe to run more than once (no duplicates).
-- Every login below uses the password:  tenant123
USE rental_pms;

CREATE TABLE IF NOT EXISTS tenant_logins (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tenant_id INT NOT NULL UNIQUE,
  email VARCHAR(160) NOT NULL UNIQUE,
  password_hash VARCHAR(100) NOT NULL,
  FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- tenants (email is unique, so existing ones are skipped)
INSERT IGNORE INTO tenants(name,email,phone) VALUES
 ('Arun Nair','arun@example.com','9400000011'),
 ('Divya Pillai','divya@example.com','9400000012'),
 ('Joseph Mathew','joseph@example.com','9400000013'),
 ('Meera Krishnan','meera@example.com','9400000014'),
 ('Sajan Varghese','sajan@example.com','9400000015');

-- properties (only if no property with that name exists)
INSERT INTO properties(name,address,city,rent,status)
SELECT * FROM (
  SELECT 'Green Villa 1' n,'21 Green Street' a,'Kottayam' c,16000 r,'occupied' s
  UNION ALL SELECT 'Green Villa 2','22 Green Street','Kottayam',17000,'occupied'
  UNION ALL SELECT 'River Flat 3A','5 River Road','Kochi',20000,'occupied'
  UNION ALL SELECT 'River Flat 3B','5 River Road','Kochi',21000,'occupied'
  UNION ALL SELECT 'Rose Cottage','9 Rose Lane','Erattupetta',14000,'occupied'
) x WHERE NOT EXISTS (SELECT 1 FROM properties p WHERE p.name = x.n);

-- one lease per tenant (only for tenants that have no lease yet)
INSERT INTO leases(property_id,tenant_id,start_date,end_date,monthly_rent)
SELECT p.id, t.id, '2026-01-01', '2026-12-31', p.rent
FROM (SELECT 'Green Villa 1' pn, 'arun@example.com' em
      UNION ALL SELECT 'Green Villa 2','divya@example.com'
      UNION ALL SELECT 'River Flat 3A','joseph@example.com'
      UNION ALL SELECT 'River Flat 3B','meera@example.com'
      UNION ALL SELECT 'Rose Cottage','sajan@example.com') m
JOIN properties p ON p.name = m.pn
JOIN tenants t ON t.email = m.em
WHERE NOT EXISTS (SELECT 1 FROM leases l WHERE l.tenant_id = t.id);

-- rent paid this month and last month (only for leases with no payments yet)
INSERT INTO payments(lease_id,amount,paid_on,method)
SELECT l.id, l.monthly_rent, DATE_FORMAT(CURDATE(),'%Y-%m-01'), 'UPI'
FROM leases l JOIN tenants t ON t.id = l.tenant_id
WHERE t.email IN ('arun@example.com','divya@example.com','joseph@example.com','meera@example.com','sajan@example.com')
  AND NOT EXISTS (SELECT 1 FROM payments y WHERE y.lease_id = l.id);
INSERT INTO payments(lease_id,amount,paid_on,method)
SELECT l.id, l.monthly_rent, DATE_SUB(DATE_FORMAT(CURDATE(),'%Y-%m-01'), INTERVAL 1 MONTH), 'Bank transfer'
FROM leases l JOIN tenants t ON t.id = l.tenant_id
WHERE t.email IN ('arun@example.com','divya@example.com','joseph@example.com','meera@example.com','sajan@example.com')
  AND (SELECT COUNT(*) FROM payments y WHERE y.lease_id = l.id) = 1;

-- the 5 tenant logins (existing ones are skipped)
INSERT IGNORE INTO tenant_logins(tenant_id,email,password_hash)
SELECT id, email, '$2a$10$XjPOq9wOLtZLY1pcLKvtj.MET.MpU8BRkOm6EQXxnGPdwCxU5fidO' FROM tenants
WHERE email IN ('arun@example.com','divya@example.com','joseph@example.com','meera@example.com','sajan@example.com');

SELECT t.name, l.email AS login_email FROM tenant_logins l JOIN tenants t ON t.id = l.tenant_id;
