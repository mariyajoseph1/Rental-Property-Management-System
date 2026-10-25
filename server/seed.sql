INSERT INTO properties(name,address,city,rent,status) VALUES
 ('Lakeview 2B','14 Lake Road','Kochi',18000,'occupied'),
 ('Palm Court 5','7 Palm Street','Kottayam',22000,'occupied'),
 ('Hill House','3 Hill Lane','Erattupetta',15000,'vacant');
INSERT INTO tenants(name,email,phone) VALUES
 ('Anita Thomas','anita@example.com','9400000001'),
 ('Rahul Menon','rahul@example.com','9400000002');
INSERT INTO leases(property_id,tenant_id,start_date,end_date,monthly_rent) VALUES
 (1,1,'2026-01-01','2026-12-31',18000),(2,2,'2026-03-01','2027-02-28',22000);
INSERT INTO payments(lease_id,amount,paid_on,method) VALUES
 (1,18000,DATE_FORMAT(CURDATE(),'%Y-%m-01'),'UPI'),(2,22000,DATE_FORMAT(CURDATE(),'%Y-%m-01'),'Bank transfer');
INSERT INTO maintenance(property_id,title,description,priority,status) VALUES
 (1,'Leaking tap','Kitchen tap drips','low','open'),
 (2,'AC not cooling','Bedroom AC','high','in progress');
