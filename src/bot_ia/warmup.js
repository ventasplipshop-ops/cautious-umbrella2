const URL = 'http://localhost:11434/api/generate';

async function warmup() {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);

    await fetch(URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      signal: controller.signal,
      body: JSON.stringify({
        model: "llama3.2:3b",
        prompt: "hola",
        stream: false
      })
    });

    clearTimeout(timeout);

    console.log('🔥 IA caliente');
  } catch (err) {
    console.error('Error warmup:', err?.message || err);
  }
}

// cada 2 minutos
setInterval(warmup, 120000);

// primera ejecución
warmup();