// MySQL pool using mysql2/promise
require('dotenv').config();
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'notesuser',
  password: process.env.DB_PASS || 'changeme',
  database: process.env.DB_NAME || 'notesdb',
  waitForConnections: true,
  connectionLimit: 5,
  queueLimit: 0
});

async function query(sql, params) {
  const [rows] = await pool.query(sql, params);
  return rows;
}

async function execute(sql, params) {
  const [result] = await pool.execute(sql, params);
  return result;
}

module.exports = { query, execute };
