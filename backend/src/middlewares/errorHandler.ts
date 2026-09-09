import { Request, Response, NextFunction } from 'express';

export interface CustomError extends Error {
  statusCode?: number;
  errors?: any[];
}

export const errorHandler = (
  err: CustomError,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Something went wrong. Please try again.';
  const errors = err.errors || [];
  const requestId = req.headers['x-request-id'] || 'req-' + Math.random().toString(36).substr(2, 9);

  // Structured JSON logging as required by PRD (Part 3.1)
  console.error(JSON.stringify({
    timestamp: new Date().toISOString(),
    request_id: requestId,
    endpoint: req.originalUrl,
    method: req.method,
    status: statusCode,
    error: message,
    errors: errors,
    stack: process.env.NODE_ENV === 'development' ? err.stack : undefined
  }));

  res.status(statusCode).json({
    success: false,
    message,
    data: null,
    errors,
    timestamp: new Date().toISOString(),
    request_id: requestId
  });
};
