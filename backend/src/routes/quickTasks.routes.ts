import { Router } from 'express';
import {
  createQuickTask,
  getQuickTasks,
  getQuickTaskById,
  updateQuickTask,
  deleteQuickTask,
  completeQuickTask,
  snoozeQuickTask,
  archiveQuickTask
} from '../controllers/quickTasks.controller.js';
import { authenticateToken } from '../middlewares/auth.js';

const router = Router();

router.use(authenticateToken as any);

router.post('/', createQuickTask as any);
router.get('/', getQuickTasks as any);
router.get('/:id', getQuickTaskById as any);
router.patch('/:id', updateQuickTask as any);
router.delete('/:id', deleteQuickTask as any);
router.post('/:id/complete', completeQuickTask as any);
router.post('/:id/snooze', snoozeQuickTask as any);
router.post('/:id/archive', archiveQuickTask as any);

export default router;
