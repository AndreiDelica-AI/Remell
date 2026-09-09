import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../middlewares/auth.js';
import prisma from '../db/client.js';

export const getHistory = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const userId = req.user!.id;
  const requestId = req.headers['x-request-id'] as string;

  try {
    const completedQuickTasks = await prisma.quickTask.findMany({
      where: { userId, status: 'completed' },
      orderBy: { completedAt: 'desc' }
    });

    const completedFocusTasks = await prisma.focusTask.findMany({
      where: { userId, status: 'completed' },
      orderBy: { completedAt: 'desc' }
    });

    // Merge and sort
    const historyItems = [
      ...completedQuickTasks.map(t => ({
        id: t.id,
        title: t.title,
        type: 'quick_task',
        completedAt: t.completedAt,
        notes: t.notes
      })),
      ...completedFocusTasks.map(t => ({
        id: t.id,
        title: t.title,
        type: 'focus_task',
        completedAt: t.completedAt,
        notes: t.description
      }))
    ].sort((a, b) => b.completedAt!.getTime() - a.completedAt!.getTime());

    return res.status(200).json({
      success: true,
      message: 'History retrieved.',
      data: historyItems,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const searchHistory = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const userId = req.user!.id;
  const { q } = req.query;
  const requestId = req.headers['x-request-id'] as string;

  try {
    const queryStr = q ? String(q) : '';

    const completedQuickTasks = await prisma.quickTask.findMany({
      where: {
        userId,
        status: 'completed',
        OR: [
          { title: { contains: queryStr, mode: 'insensitive' } },
          { notes: { contains: queryStr, mode: 'insensitive' } }
        ]
      },
      orderBy: { completedAt: 'desc' }
    });

    const completedFocusTasks = await prisma.focusTask.findMany({
      where: {
        userId,
        status: 'completed',
        OR: [
          { title: { contains: queryStr, mode: 'insensitive' } },
          { description: { contains: queryStr, mode: 'insensitive' } }
        ]
      },
      orderBy: { completedAt: 'desc' }
    });

    const historyItems = [
      ...completedQuickTasks.map(t => ({
        id: t.id,
        title: t.title,
        type: 'quick_task',
        completedAt: t.completedAt,
        notes: t.notes
      })),
      ...completedFocusTasks.map(t => ({
        id: t.id,
        title: t.title,
        type: 'focus_task',
        completedAt: t.completedAt,
        notes: t.description
      }))
    ].sort((a, b) => b.completedAt!.getTime() - a.completedAt!.getTime());

    return res.status(200).json({
      success: true,
      message: 'History search completed.',
      data: historyItems,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};
