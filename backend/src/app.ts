import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { errorHandler } from './middlewares/errorHandler.js';
import { startCleanupJob } from './jobs/cleanup.js';

// Route imports
import authRoutes from './routes/auth.routes.js';
import quickTaskRoutes from './routes/quickTasks.routes.js';
import focusTaskRoutes from './routes/focusTasks.routes.js';
import historyRoutes from './routes/history.routes.js';
import preferencesRoutes from './routes/preferences.routes.js';
import aiRoutes from './routes/ai.routes.js';

const app = express();

// Secure App Headers
app.use(helmet());

// Strict CORS Origin config
const allowedOrigins = [
  process.env.FRONTEND_URL,
  'http://localhost:8080',
  'http://localhost:5000',
  'http://127.0.0.1:8080',
  'http://127.0.0.1:5000',
].filter(Boolean) as string[];

app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true); // Allow mobile/non-browser requests
    if (allowedOrigins.indexOf(origin) !== -1 || process.env.NODE_ENV !== 'production') {
      return callback(null, true);
    }
    return callback(new Error('Not allowed by CORS'));
  },
  credentials: true
}));

app.use(express.json());
app.use(morgan('dev'));

// Rate Limiter Configurations
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 mins
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again after 15 minutes.',
    errors: ['Rate limit exceeded']
  }
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 mins
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many login attempts from this IP, please try again after 15 minutes.',
    errors: ['Auth rate limit exceeded']
  }
});

// Apply Global Rate Limiter
app.use(globalLimiter);

// Start periodic database cleanup job
startCleanupJob();

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'Remell service is healthy.',
    data: { uptime: process.uptime() },
    timestamp: new Date().toISOString(),
    request_id: 'health'
  });
});

// Mounting routers
app.use('/auth', authLimiter, authRoutes);
app.use('/quick-tasks', quickTaskRoutes);
app.use('/focus', focusTaskRoutes);
app.use('/history', historyRoutes);
app.use('/preferences', preferencesRoutes);
app.use('/ai', aiRoutes);

// Error Handling Middleware (must be after routers)
app.use(errorHandler as any);

export default app;
