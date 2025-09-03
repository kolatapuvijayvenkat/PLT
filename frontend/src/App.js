import React, { useState } from 'react';
import './App.css'; // Import the CSS file

function App() {
  const [input, setInput] = useState('');
  const [responseMessage, setResponseMessage] = useState('');

  const handleInputChange = (event) => {
    setInput(event.target.value);
  };

  const sendData = async () => {
    try {
      const response = await fetch('/api/data', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ input }),
      });
      const result = await response.json();
      setResponseMessage(result.message);
    } catch (error) {
      console.error('Error sending data:', error);
    }
  };

  return (
    <div>
      <h1>Send Data to Backend and Print</h1>
      <input
        type="text"
        value={input}
        onChange={handleInputChange}
        placeholder="Enter something"
      /><br/>
      <button onClick={sendData}>Send</button>
      {responseMessage && <p>{responseMessage}</p>}
    </div>
  );
}

export default App;
