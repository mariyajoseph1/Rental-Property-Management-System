# Rental Manager (single-page website)

The whole website (admin site + tenant page) is in ONE file: `server/public/index.html`.
Backend: Express API + MySQL (works with MySQL Workbench). One command starts everything on http://localhost:4000

```
rental-manager/
  database/all_in_one.sql        ONE script: database, tables, admin login, sample data, tenant logins (safe to run again)
  database/sample_5_users.sql    optional: adds 5 more sample tenants (safe to run again)
  server/index.js                API + serves the website
  server/tenantPortal.js         tenant login API
  server/public/index.html       THE WEBSITE: all pages, admin login and tenant login in one file
  server/.env                    your MySQL password goes here
```

## Step by step
1. Install Node.js (nodejs.org, LTS) and MySQL Server + MySQL Workbench (dev.mysql.com/downloads). Remember the MySQL root password.
2. Unzip the project. Open the `rental-manager` folder in VS Code (File > Open Folder).
3. MySQL Workbench: open your local connection, File > Open SQL Script, choose `database/all_in_one.sql`, click the lightning bolt.
4. In VS Code open `server/.env`. Change `DB_PASSWORD=your_mysql_password` to your real MySQL password. Save (Cmd+S).
5. VS Code: Terminal > New Terminal (it must be in the `rental-manager` folder), then run:
   ```bash
   npm run setup     # first time only
   npm run dev       # starts everything
   ```
   Wait for `API running on http://localhost:4000`. Keep the terminal open.
6. Open http://localhost:4000 in your browser (needs internet, the page loads React from a CDN).

## Logins
- **Admin / property manager:** http://localhost:4000  ->  `admin@rental.com` / `admin123`
- **Tenants:** http://localhost:4000/tenant  ->  anita, rahul, arun, divya, joseph, meera or sajan at `@example.com`, password `tenant123`.
  A tenant sees only their own lease(s) and payments. New tenants click "First time? Create your login" and enter the email and phone
  number saved on their tenant record, plus a new password.
- Remove a tenant login: `DELETE FROM tenant_logins WHERE email='their@email.com';`
- Change the admin login: run `DELETE FROM users;` in Workbench, edit `ADMIN_EMAIL` / `ADMIN_PASSWORD` in `.env`, restart.

## Troubleshooting
- "Request failed" or blank page: the server is not running. Run `npm run dev` from the `rental-manager` folder.
- "Access denied for user": wrong `DB_PASSWORD` in `server/.env` (save the file).
- "ECONNREFUSED" / "Database connection failed": MySQL is not running. Start MySQL (System Settings > MySQL on Mac).
- "Client does not support authentication protocol": in Workbench run
  `ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'your_mysql_password';`
- Port 4000 busy: change `PORT` in `server/.env`.
