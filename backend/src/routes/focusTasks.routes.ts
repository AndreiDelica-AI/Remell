import { Router } from 'express';
import {
  createFocusTask,
  getFocusTasks,
  updateFocusTask,
  completeFocusTask,
  generateSubtasks
} from '../controllers/focusTasks.controller.js';
import { authenticateToken } from '../middlewares/auth.js';

const router = Router();

router.use(authenticateToken as any);

router.post('/', createFocusTask as any);
router.get('/', getFocusTasks as any);
router.patch('/:id', updateFocusTask as any);
router.post('/:id/complete', completeFocusTask as any);
router.post('/:id/generate-subtasks', generateSubtasks as any);

export default router;
