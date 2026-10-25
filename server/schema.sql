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
