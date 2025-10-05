// Simple Express app (Node 18+)
const express = require('express');
const bodyParser = require('body-parser');
const db = require('./db');

const app = express();
app.use(bodyParser.json());

app.get('/healthz', (req, res) => res.status(200).send('ok'));
app.get('/', (req, res) => res.status(200).send('Hello from 3‑Tier on AWS (Node.js)!'));

app.get('/notes', async (req, res) => {
  try {
    const rows = await db.query('SELECT id, text, created_at FROM notes ORDER BY id DESC');
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'db_error' });
  }
});

app.post('/notes', async (req, res) => {
  const text = (req.body?.text || '').trim();
  if (!text) return res.status(400).json({ error: 'text_required' });
  try {
    await db.execute('INSERT INTO notes(text) VALUES (?)', [text]);
    res.status(201).json({ status: 'created' });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'db_error' });
  }
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Server running on ${port}`));
