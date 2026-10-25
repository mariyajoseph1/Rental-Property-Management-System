-- ============================================================
-- Rental Manager: ALL IN ONE database script
-- Creates the database and tables, the admin login, sample properties,
-- 7 tenants (with leases and payments) and tenant logins.
-- Run it in MySQL Workbench (File > Open SQL Script, then the lightning bolt).
-- Safe to run more than once: it never creates duplicates.
--
--   Admin login   : admin@rental.com / admin123   (website: http://localhost:5173)
--   Tenant logins : anita, rahul, arun, divya, joseph, meera, sajan @example.com
--                   password for all: tenant123    (website: http://localhost:5173/tenant)
-- ============================================================

-- Run automatically on server start; you can also run it in MySQL Workbench.
CREATE DATABASE IF NOT EXISTS rental_pms;
USE rental_pms;

CREATE TABLE IF NOT EXISTS properties (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  address VARCHAR(255) NOT NULL,
  city VARCHAR(80),
  rent DECIMAL(10,2) NOT NULL DEFAULT 0,
  status ENUM('vacant','occupied','maintenance') NOT NULL DEFAULT 'vacant'
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS tenants (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(160) UNIQUE,
  phone VARCHAR(30)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS leases (
  id INT AUTO_INCREMENT PRIMARY KEY,
  property_id INT NOT NULL,
  tenant_id INT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  monthly_rent DECIMAL(10,2) NOT NULL,
  FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE,
  FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  lease_id INT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  paid_on DATE NOT NULL,
  method VARCHAR(40),
  FOREIGN KEY (lease_id) REFERENCES leases(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS maintenance (
  id INT AUTO_INCREMENT PRIMARY KEY,
  property_id INT NOT NULL,
  title VARCHAR(160) NOT NULL,
  description TEXT,
  priority ENUM('low','medium','high') NOT NULL DEFAULT 'medium',
  status ENUM('open','in progress','done') NOT NULL DEFAULT 'open',
  FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(160) NOT NULL UNIQUE,
  password_hash VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- tenant logins for the tenant page (/tenant)
CREATE TABLE IF NOT EXISTS tenant_logins (
  id INT AUTO_INCREMENT PRIMARY KEY,
  tenant_id INT NOT NULL UNIQUE,
  email VARCHAR(160) NOT NULL UNIQUE,
  password_hash VARCHAR(100) NOT NULL,
  FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE
) ENGINE=InnoDB;


-- admin login
INSERT IGNORE INTO users(name,email,password_hash) VALUES ('Administrator','admin@rental.com','$2a$10$2aRDEhHyAyov.H1uw.QJp.FrBHhfQkAVKuk/2p3q6kSUqgZsi2xmG');

-- properties (added only if a property with that name does not exist yet)
INSERT INTO properties(name,address,city,rent,status)
SELECT * FROM (
  SELECT 'Lakeview 2B' n,'14 Lake Road' a,'Kochi' c,18000 r,'occupied' s
  UNION ALL SELECT 'Palm Court 5','7 Palm Street','Kottayam',22000,'occupied'
  UNION ALL SELECT 'Hill House','3 Hill Lane','Erattupetta',15000,'vacant'
  UNION ALL SELECT 'Green Villa 1','21 Green Street','Kottayam',16000,'occupied'
  UNION ALL SELECT 'Green Villa 2','22 Green Street','Kottayam',17000,'occupied'
  UNION ALL SELECT 'River Flat 3A','5 River Road','Kochi',20000,'occupied'
  UNION ALL SELECT 'River Flat 3B','5 River Road','Kochi',21000,'occupied'
  UNION ALL SELECT 'Rose Cottage','9 Rose Lane','Erattupetta',14000,'occupied'
) x WHERE NOT EXISTS (SELECT 1 FROM properties p WHERE p.name = x.n);

-- tenants (email is unique, so existing ones are skipped)
INSERT IGNORE INTO tenants(name,email,phone) VALUES
 ('Anita Thomas','anita@example.com','9400000001'),
 ('Rahul Menon','rahul@example.com','9400000002'),
 ('Arun Nair','arun@example.com','9400000011'),
 ('Divya Pillai','divya@example.com','9400000012'),
 ('Joseph Mathew','joseph@example.com','9400000013'),
 ('Meera Krishnan','meera@example.com','9400000014'),
 ('Sajan Varghese','sajan@example.com','9400000015');

-- one lease per tenant (only for tenants that have no lease yet)
INSERT INTO leases(property_id,tenant_id,start_date,end_date,monthly_rent)
SELECT p.id, t.id, m.sd, m.ed, p.rent
FROM (SELECT 'Lakeview 2B' pn,'anita@example.com' em,'2026-01-01' sd,'2026-12-31' ed
      UNION ALL SELECT 'Palm Court 5','rahul@example.com','2026-03-01','2027-02-28'
      UNION ALL SELECT 'Green Villa 1','arun@example.com','2026-01-01','2026-12-31'
      UNION ALL SELECT 'Green Villa 2','divya@example.com','2026-01-01','2026-12-31'
      UNION ALL SELECT 'River Flat 3A','joseph@example.com','2026-01-01','2026-12-31'
      UNION ALL SELECT 'River Flat 3B','meera@example.com','2026-01-01','2026-12-31'
      UNION ALL SELECT 'Rose Cottage','sajan@example.com','2026-01-01','2026-12-31') m
JOIN properties p ON p.name = m.pn
JOIN tenants t ON t.email = m.em
WHERE NOT EXISTS (SELECT 1 FROM leases l WHERE l.tenant_id = t.id);

-- rent paid this month and last month (only for leases that have no payments yet)
INSERT INTO payments(lease_id,amount,paid_on,method)
SELECT l.id, l.monthly_rent, DATE_FORMAT(CURDATE(),'%Y-%m-01'), 'UPI'
FROM leases l WHERE NOT EXISTS (SELECT 1 FROM payments y WHERE y.lease_id = l.id);
INSERT INTO payments(lease_id,amount,paid_on,method)
SELECT l.id, l.monthly_rent, DATE_SUB(DATE_FORMAT(CURDATE(),'%Y-%m-01'), INTERVAL 1 MONTH), 'Bank transfer'
FROM leases l WHERE (SELECT COUNT(*) FROM payments y WHERE y.lease_id = l.id) = 1;

-- two sample maintenance requests (only if there are none)
INSERT INTO maintenance(property_id,title,description,priority,status)
SELECT p.id, m.t, m.d, m.pr, m.st
FROM (SELECT 'Lakeview 2B' pn,'Leaking tap' t,'Kitchen tap drips' d,'low' pr,'open' st
      UNION ALL SELECT 'Palm Court 5','AC not cooling','Bedroom AC','high','in progress') m
JOIN properties p ON p.name = m.pn
WHERE NOT EXISTS (SELECT 1 FROM maintenance);

-- tenant logins (password: tenant123)
INSERT IGNORE INTO tenant_logins(tenant_id,email,password_hash)
SELECT id, email, '$2a$10$3a5WSuqgAU3IZDIsDoze7.odoEREUtKI54WhdLPUbVm2w9b3gQqBq' FROM tenants WHERE email IN ('anita@example.com','rahul@example.com','arun@example.com','divya@example.com','joseph@example.com','meera@example.com','sajan@example.com');

SELECT 'properties' AS what, COUNT(*) AS rows_in_table FROM properties
UNION ALL SELECT 'tenants', COUNT(*) FROM tenants
UNION ALL SELECT 'leases', COUNT(*) FROM leases
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'tenant logins', COUNT(*) FROM tenant_logins;
