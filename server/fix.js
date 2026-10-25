require('dotenv').config();
const mysql=require('mysql2/promise');
const bcrypt=require('bcryptjs');
(async()=>{
const db=await mysql.createConnection({host:'localhost',port:3306,user:'root',password:'mariya123',database:'rental_pms'});
console.log('DB Connected! - Good!');
const hash=await bcrypt.hash('tenant123',10);
console.log('Creating tenant logins...');
await db.query(`CREATE TABLE IF NOT EXISTS tenant_logins (id INT AUTO_INCREMENT PRIMARY KEY, tenant_id INT NOT NULL UNIQUE, email VARCHAR(190) NOT NULL UNIQUE, password_hash VARCHAR(255) NOT NULL)`);
await db.query('DELETE FROM tenant_logins');
const list=[[1,'arun@example.com'],[2,'divya@example.com'],[3,'joseph@example.com'],[4,'meera@example.com'],[5,'sajan@example.com']];
for(const [id,email] of list){
await db.query('INSERT INTO tenant_logins (tenant_id,email,password_hash) VALUES (?,?,?)',[id,email,hash]);
console.log('OK',email,'/ tenant123');
}
const [rows]=await db.query('SELECT email FROM tenant_logins');
console.log('Total logins:',rows.length);
console.log('ALL DONE!');
await db.end();
})();
