const express = require('express');
const path = require('path');
const bodyParser = require('body-parser');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware to parse JSON bodies
app.use(bodyParser.json());

// Serve static files from the React app's build directory
app.use(express.static(path.join(__dirname, 'build')));

// API endpoint to receive data
app.post('/api/data', (req, res) => {
    const userInput = req.body.input;
    console.log('Received input:', userInput);
    res.json({ message: `Data received successfully : ${userInput}` });
});

// Catch-all handler to serve the React app for any other routes
app.get('/*', (req, res) => {
  res.sendFile(path.join(__dirname, 'build', 'index.html'));
});


// Start the server
app.listen(PORT, () => {
    console.log(`Server is running on https://localhost:${PORT}`);
});
