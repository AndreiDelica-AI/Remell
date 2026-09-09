import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../middlewares/auth.js';
import prisma from '../db/client.js';
import { AiService } from '../services/ai.service.js';

export const createFocusTask = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { title, description, estimatedMinutes, priority } = req.body;
  const userId = req.user!.id;
  const requestId = req.headers['x-request-id'] as string;

  try {
    if (!title) {
      return res.status(400).json({
        success: false,
        message: 'Task title is required.',
        data: null,
        errors: ['Missing title'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    // Auto-generate subtasks as specified in AI settings
    const subtaskTitles = AiService.generateSubtasks(title);

    const task = await prisma.focusTask.create({
      data: {
        userId,
        title,
        description,
        estimatedMinutes: estimatedMinutes || 30,
        priority: priority || 'medium',
        status: 'pending',
        subtasks: {
          create: subtaskTitles.map((subTitle, idx) => ({
            title: subTitle,
            orderIndex: idx,
            status: 'pending'
          }))
        }
      },
      include: {
        subtasks: true
      }
    });

    return res.status(201).json({
      success: true,
      message: 'Focus Task created.',
      data: task,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const getFocusTasks = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const userId = req.user!.id;
  const requestId = req.headers['x-request-id'] as string;
  const { status } = req.query;

  try {
    const tasks = await prisma.focusTask.findMany({
      where: {
        userId,
        status: status ? String(status) : { in: ['pending', 'active'] }
      },
      include: {
        subtasks: {
          orderBy: { orderIndex: 'asc' }
        }
      },
      orderBy: {
        createdAt: 'asc' // FIFO or priority order
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Focus tasks retrieved.',
      data: tasks,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const updateFocusTask = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { id } = req.params;
  const userId = req.user!.id;
  const { title, description, estimatedMinutes, priority, status, progress, subtasks } = req.body;
  const requestId = req.headers['x-request-id'] as string;

  try {
    const task = await prisma.focusTask.findFirst({
      where: { id, userId }
    });

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Focus task not found.',
        data: null,
        errors: ['Task not found'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    // Process subtask status updates if passed
    if (subtasks && Array.isArray(subtasks)) {
      for (const st of subtasks) {
        await prisma.subtask.updateMany({
          where: { id: st.id, focusTaskId: id },
          data: {
            status: st.status,
            completedAt: st.status === 'completed' ? new Date() : null
          }
        });
      }
    }

    // Re-evaluate task progress based on subtasks
    const allSubtasks = await prisma.subtask.findMany({ where: { focusTaskId: id } });
    const completedCount = allSubtasks.filter(st => st.status === 'completed').length;
    const computedProgress = allSubtasks.length > 0 ? (completedCount / allSubtasks.length) : (progress || 0.0);

    const updatedTask = await prisma.focusTask.update({
      where: { id },
      data: {
        title,
        description,
        estimatedMinutes,
        priority,
        status,
        progress: computedProgress,
        completedAt: status === 'completed' ? new Date() : undefined
      },
      include: {
        subtasks: {
          orderBy: { orderIndex: 'asc' }
        }
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Focus task updated.',
      data: updatedTask,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const completeFocusTask = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { id } = req.params;
  const userId = req.user!.id;
  const requestId = req.headers['x-request-id'] as string;

  try {
    const task = await prisma.focusTask.findFirst({
      where: { id, userId }
    });

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Focus task not found.',
        data: null,
        errors: ['Task not found'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const completedTask = await prisma.focusTask.update({
      where: { id },
      data: {
        status: 'completed',
        completedAt: new Date()
      },
      include: {
        subtasks: true
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Nice work. I\'ve taken that off your mind.',
      data: completedTask,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const generateSubtasks = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { id } = req.params;
  const userId = req.user!.id;
  const requestId = req.headers['x-request-id'] as string;

  try {
    const task = await prisma.focusTask.findFirst({
      where: { id, userId }
    });

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Focus task not found.',
        data: null,
        errors: ['Task not found'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const subtaskTitles = AiService.generateSubtasks(task.title);

    // Delete existing and recreate
    await prisma.subtask.deleteMany({ where: { focusTaskId: id } });

    const updatedTask = await prisma.focusTask.update({
      where: { id },
      data: {
        subtasks: {
          create: subtaskTitles.map((title, idx) => ({
            title,
            orderIndex: idx,
            status: 'pending'
          }))
        }
      },
      include: {
        subtasks: {
          orderBy: { orderIndex: 'asc' }
        }
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Subtasks generated successfully.',
      data: updatedTask,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};
