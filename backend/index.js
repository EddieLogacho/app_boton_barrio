require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Conexión a la base de datos boton_barrio
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'boton_barrio',
  password: process.env.DB_PASSWORD,
  port: 5432,
});

// Ruta de prueba, para saber si el servidor está vivo
app.get('/', (req, res) => {
  res.send('Servidor de Botón de Barrio funcionando 🏘️');
});

// Ruta de login
app.post('/login', async (req, res) => {
  const { correo, password } = req.body;

  try {
    const resultado = await pool.query(
      'SELECT * FROM usuarios WHERE correo = $1 AND password = $2',
      [correo, password]
    );

    if (resultado.rows.length > 0) {
      res.json({ exito: true, usuario: resultado.rows[0] });
    } else {
      res.status(401).json({ exito: false, mensaje: 'Correo o contraseña incorrectos' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ exito: false, mensaje: 'Error en el servidor' });
  }
});

// Ruta de registro
app.post('/registro', async (req, res) => {
  const { nombre, apellido, correo, password } = req.body;

  try {
    const existe = await pool.query('SELECT id FROM usuarios WHERE correo = $1', [correo]);

    if (existe.rows.length > 0) {
      return res.status(400).json({ exito: false, mensaje: 'Ese correo ya está registrado' });
    }

    const resultado = await pool.query(
      'INSERT INTO usuarios (nombre, apellido, correo, password) VALUES ($1, $2, $3, $4) RETURNING id, nombre, apellido, correo',
      [nombre, apellido, correo, password]
    );

    res.json({ exito: true, usuario: resultado.rows[0] });
  } catch (error) {
    console.error(error);
    res.status(500).json({ exito: false, mensaje: 'Error en el servidor' });
  }
});

// Ruta para obtener los datos de un usuario por su correo
app.get('/usuario/:correo', async (req, res) => {
  const { correo } = req.params;

  try {
    const resultado = await pool.query(
      'SELECT id, nombre, apellido, correo, fecha_registro FROM usuarios WHERE correo = $1',
      [correo]
    );

    if (resultado.rows.length > 0) {
      res.json({ exito: true, usuario: resultado.rows[0] });
    } else {
      res.status(404).json({ exito: false, mensaje: 'Usuario no encontrado' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ exito: false, mensaje: 'Error en el servidor' });
  }
});

// Ruta para obtener todos los eventos
app.get('/eventos', async (req, res) => {
  try {
    const resultado = await pool.query('SELECT * FROM eventos ORDER BY fecha ASC');
    res.json({ exito: true, eventos: resultado.rows });
  } catch (error) {
    console.error(error);
    res.status(500).json({ exito: false, mensaje: 'Error en el servidor' });
  }
});

// Ruta para crear un nuevo evento
app.post('/eventos', async (req, res) => {
  const { titulo, descripcion, fecha, lugar } = req.body;

  try {
    const resultado = await pool.query(
      'INSERT INTO eventos (titulo, descripcion, fecha, lugar) VALUES ($1, $2, $3, $4) RETURNING *',
      [titulo, descripcion, fecha, lugar]
    );
    res.json({ exito: true, evento: resultado.rows[0] });
  } catch (error) {
    console.error(error);
    res.status(500).json({ exito: false, mensaje: 'Error en el servidor' });
  }
});

// Ruta para obtener todas las alertas
app.get('/alertas', async (req, res) => {
  try {
    const resultado = await pool.query('SELECT * FROM alertas ORDER BY fecha DESC');
    res.json({ exito: true, alertas: resultado.rows });
  } catch (error) {
    console.error(error);
    res.status(500).json({ exito: false, mensaje: 'Error en el servidor' });
  }
});

// Ruta para crear una nueva alerta
app.post('/alertas', async (req, res) => {
  const { tipo, mensaje, latitud, longitud, creado_por, foto } = req.body;

  try {
    const resultado = await pool.query(
      'INSERT INTO alertas (tipo, mensaje, latitud, longitud, creado_por, foto) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [tipo, mensaje, latitud, longitud, creado_por, foto]
    );
    res.json({ exito: true, alerta: resultado.rows[0] });
  } catch (error) {
    console.error(error);
    res.status(500).json({ exito: false, mensaje: 'Error en el servidor' });
  }
});

// Ruta para agregar o actualizar la descripción y/o la foto de una alerta
app.put('/alertas/:id', async (req, res) => {
  const { id } = req.params;
  const { mensaje, foto } = req.body;

  const tieneMensaje = typeof mensaje === 'string' && mensaje.trim() !== '';
  const tieneFoto = typeof foto === 'string' && foto !== '';

  if (!tieneMensaje && !tieneFoto) {
    return res.status(400).json({ exito: false, mensaje: 'Envía una descripción o una foto' });
  }

  try {
    const resultado = await pool.query(
      `UPDATE alertas
       SET mensaje = COALESCE($1, mensaje),
           foto = COALESCE($2, foto)
       WHERE id = $3
       RETURNING id, tipo, mensaje, latitud, longitud, creado_por, fecha`,
      [tieneMensaje ? mensaje.trim() : null, tieneFoto ? foto : null, id]
    );

    if (resultado.rows.length === 0) {
      return res.status(404).json({ exito: false, mensaje: 'Alerta no encontrada' });
    }

    res.json({ exito: true, alerta: resultado.rows[0] });
  } catch (error) {
    console.error(error);
    res.status(500).json({ exito: false, mensaje: 'Error en el servidor' });
  }
});

// Ruta del asistente de seguridad con IA
app.post('/asistente', async (req, res) => {
  const { pregunta } = req.body;

  try {
    const modelo = genAI.getGenerativeModel({ model: 'gemini-3.6-flash' });

    const prompt = `Eres un asistente de seguridad comunitaria para una app llamada "Botón de Barrio", usada por vecinos en Ecuador. Responde de forma breve, clara y práctica (máximo 4-5 líneas) a la siguiente pregunta o situación de seguridad: ${pregunta}`;

    const resultado = await modelo.generateContent(prompt);
    const respuestaTexto = resultado.response.text();

    res.json({ exito: true, respuesta: respuestaTexto });
  } catch (error) {
    console.error(error);
    res.status(500).json({ exito: false, mensaje: 'Error al contactar al asistente de IA' });
  }
});

const PORT = 3001;
app.listen(PORT, () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});