const express = require('express');
const path = require('path');
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Locate the ATM executable
let exeName = 'atm';
if (os.platform() === 'win32') {
    if (fs.existsSync(path.join(__dirname, 'atm.exe'))) {
        exeName = 'atm.exe';
    } else if (fs.existsSync(path.join(__dirname, 'atm'))) {
        exeName = 'atm';
    } else {
        console.error('ERROR: Could not find atm or atm.exe in', __dirname);
        process.exit(1);
    }
} else {
    exeName = './atm';
}
const fullPath = path.join(__dirname, exeName);
console.log('Spawning ATM with pipes from:', fullPath);

// Spawn the process with standard pipes
const atm = spawn(fullPath, [], {
    stdio: ['pipe', 'pipe', 'pipe'],
    cwd: __dirname,
    env: process.env,
});

let outputBuffer = '';
let pendingResolve = null;
let resolveTimer = null;

// Collect all output (stdout + stderr)
atm.stdout.on('data', (data) => {
    const str = data.toString();
    console.log('STDOUT:', str);
    outputBuffer += str;
    flushIfPending();
});

atm.stderr.on('data', (data) => {
    const str = data.toString();
    console.log('STDERR:', str);
    outputBuffer += str;
    flushIfPending();
});

function flushIfPending() {
    if (pendingResolve) {
        clearTimeout(resolveTimer);
        resolveTimer = setTimeout(() => {
            const response = outputBuffer;
            outputBuffer = '';
            const resolveCopy = pendingResolve;
            pendingResolve = null;
            resolveTimer = null;
            resolveCopy(response);
        }, 500); // wait for complete command output
    }
}

atm.on('exit', (code) => {
    console.log(`ATM process exited with code ${code}`);
});

function sendCommand(cmd) {
    return new Promise((resolve, reject) => {
        if (atm.exitCode !== null) {
            reject(new Error('ATM process already exited'));
            return;
        }

        const timeout = setTimeout(() => {
            pendingResolve = null;
            reject(new Error('Timeout waiting for ATM response'));
        }, 5000);

        pendingResolve = (response) => {
            clearTimeout(timeout);
            resolve(response);
        };

        console.log(`Writing command: "${cmd}"`);
        atm.stdin.write(cmd + '\n'); // newline triggers the parser
    });
}

app.post('/command', async (req, res) => {
    const { command } = req.body;
    if (!command) return res.status(400).send('No command');

    try {
        const response = await sendCommand(command);
        res.json({ response });
    } catch (err) {
        console.error('Command error:', err.message);
        res.status(500).send('Backend error: ' + err.message);
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});