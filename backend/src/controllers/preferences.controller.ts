import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../middlewares/auth.js';
import prisma from '../db/client.js';

export const getPreferences = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const userId = req.user!.id;
  const requestId = req.headers['x-request-id'] as string;

  try {
    const preferences = await prisma.userPreferences.findUnique({
      where: { userId }
    });

    return res.status(200).json({
      success: true,
      message: 'Preferences retrieved.',
      data: preferences,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const updatePreferences = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const userId = req.user!.id;
  const { homeLayout, reminderStyle, quickTaskSort, focusCount, wakeTime, sleepTime, language, theme } = req.body;
  const requestId = req.headers['x-request-id'] as string;

  try {
    const preferences = await prisma.userPreferences.update({
      where: { userId },
      data: {
        homeLayout,
        reminderStyle,
        quickTaskSort,
        focusCount,
        wakeTime,
        sleepTime,
        language,
        theme
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Preferences updated.',
      data: preferences,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};
