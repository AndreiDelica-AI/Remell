import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../middlewares/auth.js';
import prisma from '../db/client.js';
import { AiService } from '../services/ai.service.js';

export const createQuickTask = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { title, notes, dueAt, priority, reminderMode } = req.body;
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

    // Auto-parse input title using rule engine
    const parsed = await AiService.parseNaturalLanguage(title);

    const task = await prisma.quickTask.create({
      data: {
        userId,
        title: parsed.title,
        notes: notes || parsed.notes || null,
        dueAt: dueAt ? new Date(dueAt) : parsed.dueAt,
        priority: priority || parsed.priority,
        reminderMode: reminderMode || parsed.reminderMode,
        aiClassification: 'quick_task',
        confidenceScore: parsed.confidenceScore
      }
    });

    return res.status(201).json({
      success: true,
      message: 'Quick Task created.',
      data: task,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const getQuickTasks = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const userId = req.user!.id;
  const requestId = req.headers['x-request-id'] as string;
  const { status } = req.query;

  try {
    const tasks = await prisma.quickTask.findMany({
      where: {
        userId,
        status: status ? String(status) : { not: 'archived' }
      },
      orderBy: {
        createdAt: 'desc'
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Quick tasks retrieved.',
      data: tasks,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const getQuickTaskById = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { id } = req.params;
  const userId = req.user!.id;
  const requestId = req.headers['x-request-id'] as string;

  try {
    const task = await prisma.quickTask.findFirst({
      where: { id, userId }
    });

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Quick task not found.',
        data: null,
        errors: ['Task not found'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Quick task retrieved.',
      data: task,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const updateQuickTask = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { id } = req.params;
  const userId = req.user!.id;
  const { title, notes, dueAt, priority, reminderMode, status } = req.body;
  const requestId = req.headers['x-request-id'] as string;

  try {
    const task = await prisma.quickTask.findFirst({
      where: { id, userId }
    });

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Quick task not found.',
        data: null,
        errors: ['Task not found'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const updatedTask = await prisma.quickTask.update({
      where: { id },
      data: {
        title,
        notes,
        dueAt: dueAt ? new Date(dueAt) : undefined,
        priority,
        reminderMode,
        status,
        completedAt: status === 'completed' ? new Date() : undefined
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Quick task updated.',
      data: updatedTask,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const deleteQuickTask = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { id } = req.params;
  const userId = req.user!.id;
  const requestId = req.headers['x-request-id'] as string;

  try {
    const task = await prisma.quickTask.findFirst({
      where: { id, userId }
    });

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Quick task not found.',
        data: null,
        errors: ['Task not found'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    // Soft delete by archiving as specified in DB standards
    const archivedTask = await prisma.quickTask.update({
      where: { id },
      data: {
        status: 'archived',
        archivedAt: new Date()
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Quick task deleted.',
      data: archivedTask,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const completeQuickTask = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { id } = req.params;
  const userId = req.user!.id;
  const requestId = req.headers['x-request-id'] as string;

  try {
    const task = await prisma.quickTask.findFirst({
      where: { id, userId }
    });

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Quick task not found.',
        data: null,
        errors: ['Task not found'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const completedTask = await prisma.quickTask.update({
      where: { id },
      data: {
        status: 'completed',
        completedAt: new Date()
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Nice work. I\'ve taken that off your mind.', // Required brand completion phrase!
      data: completedTask,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const snoozeQuickTask = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { id } = req.params;
  const { minutes } = req.body; // e.g. 10, 30, 60
  const userId = req.user!.id;
  const requestId = req.headers['x-request-id'] as string;

  try {
    const task = await prisma.quickTask.findFirst({
      where: { id, userId }
    });

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Quick task not found.',
        data: null,
        errors: ['Task not found'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const snoozeMins = parseInt(minutes) || 30;
    const newDueDate = new Date(Date.now() + snoozeMins * 60 * 1000);

    const snoozedTask = await prisma.quickTask.update({
      where: { id },
      data: {
        dueAt: newDueDate
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Quick task snoozed.',
      data: snoozedTask,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const archiveQuickTask = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { id } = req.params;
  const userId = req.user!.id;
  const requestId = req.headers['x-request-id'] as string;

  try {
    const task = await prisma.quickTask.findFirst({
      where: { id, userId }
    });

    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Quick task not found.',
        data: null,
        errors: ['Task not found'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const archivedTask = await prisma.quickTask.update({
      where: { id },
      data: {
        status: 'archived',
        archivedAt: new Date()
      }
    });

    return res.status(200).json({
      success: true,
      message: 'Quick task archived.',
      data: archivedTask,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};
