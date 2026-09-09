import app from './app.js';
import { config } from './config/index.js';

app.listen(config.port, () => {
  console.log(`[Remell Server] Service running on port ${config.port}`);
});
