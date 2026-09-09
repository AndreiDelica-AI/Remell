import dotenv from 'dotenv';
dotenv.config();

export const config = {
  port: process.env.PORT || '5000',
  databaseUrl: process.env.DATABASE_URL || '',
  jwtSecret: process.env.JWT_SECRET || 'jwt_access_secret',
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET || 'jwt_refresh_secret',
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
  openaiApiKey: process.env.OPENAI_API_KEY || 'mock_key',
};
