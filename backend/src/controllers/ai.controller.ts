import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../middlewares/auth.js';
import { AiService } from '../services/ai.service.js';
import prisma from '../db/client.js';

export const classifyTask = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { input } = req.body;
  const requestId = req.headers['x-request-id'] as string;

  try {
    if (!input) {
      return res.status(400).json({
        success: false,
        message: 'Input text is required.',
        data: null,
        errors: ['Missing input'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const parsed = await AiService.parseNaturalLanguage(input);

    return res.status(200).json({
      success: true,
      message: 'Task classified.',
      data: parsed,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const suggestReminder = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { input } = req.body;
  const requestId = req.headers['x-request-id'] as string;

  try {
    if (!input) {
      return res.status(400).json({
        success: false,
        message: 'Input is required.',
        data: null,
        errors: ['Missing input'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const parsed = await AiService.parseNaturalLanguage(input);

    return res.status(200).json({
      success: true,
      message: 'Reminder time suggested.',
      data: {
        suggestedTime: parsed.dueAt || new Date(Date.now() + 60 * 60 * 1000), // Default to 1 hour if not parsed
        confidence: parsed.confidenceScore
      },
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const generateSubtasksEndpoint = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { title, notes, input } = req.body;
  const requestId = req.headers['x-request-id'] as string;

  try {
    const textToParse = notes || input || title;
    if (!textToParse) {
      return res.status(400).json({
        success: false,
        message: 'Task title or notes is required.',
        data: null,
        errors: ['Missing text to parse'],
        timestamp: new Date().toISOString(),
        request_id: requestId
      });
    }

    const subtasks = await AiService.generateSubtasksFromNotes(textToParse);

    return res.status(200).json({
      success: true,
      message: 'Subtasks generated.',
      data: { subtasks },
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const rewriteTask = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const { title } = req.body;
  const requestId = req.headers['x-request-id'] as string;

  try {
    // Normalizes title to clean friendly assistant prompt
    const cleaned = title ? title.trim() : '';

    return res.status(200).json({
      success: true,
      message: 'Task rewritten.',
      data: {
        rewrittenTitle: cleaned
      },
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};

export const focusSelection = async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  const userId = req.user!.id;
  const requestId = req.headers['x-request-id'] as string;

  try {
    // Selection logic: Finds the oldest pending focus task with highest priority
    const pendingTasks = await prisma.focusTask.findMany({
      where: { userId, status: 'pending' }
    });

    const priorityWeight: Record<string, number> = {
      high: 3,
      medium: 2,
      low: 1
    };

    pendingTasks.sort((a, b) => {
      const pA = priorityWeight[a.priority.toLowerCase()] || 0;
      const pB = priorityWeight[b.priority.toLowerCase()] || 0;
      if (pB !== pA) {
        return pB - pA;
      }
      return a.createdAt.getTime() - b.createdAt.getTime();
    });

    const nextFocusTask = pendingTasks[0] || null;

    return res.status(200).json({
      success: true,
      message: 'Optimal focus task selected.',
      data: nextFocusTask || null,
      timestamp: new Date().toISOString(),
      request_id: requestId
    });
  } catch (error) {
    next(error);
  }
};
