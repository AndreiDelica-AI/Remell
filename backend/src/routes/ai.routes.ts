import { Router } from 'express';
import {
  classifyTask,
  suggestReminder,
  generateSubtasksEndpoint,
  rewriteTask,
  focusSelection
} from '../controllers/ai.controller.js';
import { authenticateToken } from '../middlewares/auth.js';

const router = Router();

router.use(authenticateToken as any);

router.post('/classify', classifyTask as any);
router.post('/suggest-reminder', suggestReminder as any);
router.post('/generate-subtasks', generateSubtasksEndpoint as any);
router.post('/rewrite-task', rewriteTask as any);
router.post('/focus-selection', focusSelection as any);

export default router;
