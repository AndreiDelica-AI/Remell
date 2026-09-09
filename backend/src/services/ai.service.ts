import { config } from '../config/index.js';
import { exec } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export interface ParsedTask {
  title: string;
  notes?: string;
  dueAt?: Date;
  priority: string;
  reminderMode: string;
  confidenceScore: number;
}

export class AiService {
  /**
   * Local LLM-based Natural Language Parser
   * Spawns python parser to run local GGUF model inference.
   */
  static async parseNaturalLanguage(input: string): Promise<ParsedTask> {
    return new Promise((resolve) => {
      const pythonScript = path.join(__dirname, 'parse_task.py');
      // Escape double quotes in input
      const escapedInput = input.replace(/"/g, '\\"');
      
      exec(`python "${pythonScript}" "${escapedInput}"`, (error, stdout, stderr) => {
        if (error) {
          console.error(`[AI Parser] Error executing python script: ${error.message}`);
          console.error(`[AI Parser] stderr: ${stderr}`);
          resolve(AiService.parseNaturalLanguageRuleEngine(input));
          return;
        }

        try {
          const parsedOutput = JSON.parse(stdout.trim());
          if (parsedOutput.tasks && parsedOutput.tasks.length > 0) {
            const firstTask = parsedOutput.tasks[0];
            resolve({
              title: firstTask.title,
              dueAt: firstTask.due ? new Date(firstTask.due) : undefined,
              priority: (firstTask.priority || 'medium').toLowerCase(),
              reminderMode: 'smart',
              confidenceScore: 0.95
            });
            return;
          }
        } catch (parseError) {
          console.error(`[AI Parser] Failed parsing LLM output: ${parseError}`);
          console.error(`[AI Parser] Raw output: ${stdout}`);
        }

        resolve(AiService.parseNaturalLanguageRuleEngine(input));
      });
    });
  }

  /**
   * Deterministic Natural Language Parser (Rule Engine)
   * Extracts date/time patterns from user inputs offline/instantly as a fallback.
   */
  static parseNaturalLanguageRuleEngine(input: string): ParsedTask {
    const lowerInput = input.toLowerCase();
    let title = input;
    let dueAt: Date | undefined = undefined;
    let priority = 'medium';
    let confidenceScore = 0.8;

    // Simple parser matching "tomorrow at X", "today at X", "in X minutes"
    const tomorrowRegex = /tomorrow(?:\s+at\s+(\d+)(?::(\d+))?\s*(am|pm)?)?/i;
    const todayRegex = /today(?:\s+at\s+(\d+)(?::(\d+))?\s*(am|pm)?)?/i;
    const inMinsRegex = /in\s+(\d+)\s*(mins|min|minutes)/i;
    const inHoursRegex = /in\s+(\d+)\s*(hours|hour|hrs|hr)/i;

    const now = new Date();

    if (tomorrowRegex.test(lowerInput)) {
      const match = tomorrowRegex.exec(lowerInput);
      dueAt = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
      if (match && match[1]) {
        let hours = parseInt(match[1]);
        const mins = match[2] ? parseInt(match[2]) : 0;
        const ampm = match[3] ? match[3].toLowerCase() : 'pm'; // Default to PM if not specified (e.g. at 6)
        
        if (ampm === 'pm' && hours < 12) hours += 12;
        if (ampm === 'am' && hours === 12) hours = 0;
        
        dueAt.setHours(hours, mins, 0, 0);
      } else {
        // Default tomorrow time (e.g. 9 AM)
        dueAt.setHours(9, 0, 0, 0);
      }
      title = input.replace(new RegExp(tomorrowRegex, 'i'), '').trim();
      confidenceScore = 0.95;
    } else if (todayRegex.test(lowerInput)) {
      const match = todayRegex.exec(lowerInput);
      dueAt = new Date(now);
      if (match && match[1]) {
        let hours = parseInt(match[1]);
        const mins = match[2] ? parseInt(match[2]) : 0;
        const ampm = match[3] ? match[3].toLowerCase() : 'pm';

        if (ampm === 'pm' && hours < 12) hours += 12;
        if (ampm === 'am' && hours === 12) hours = 0;

        dueAt.setHours(hours, mins, 0, 0);
      } else {
        // Default today time (e.g. 18:00)
        dueAt.setHours(18, 0, 0, 0);
      }
      title = input.replace(new RegExp(todayRegex, 'i'), '').trim();
      confidenceScore = 0.95;
    } else if (inMinsRegex.test(lowerInput)) {
      const match = inMinsRegex.exec(lowerInput);
      if (match && match[1]) {
        const mins = parseInt(match[1]);
        dueAt = new Date(now.getTime() + mins * 60 * 1000);
      }
      title = input.replace(new RegExp(inMinsRegex, 'i'), '').trim();
      confidenceScore = 0.9;
    } else if (inHoursRegex.test(lowerInput)) {
      const match = inHoursRegex.exec(lowerInput);
      if (match && match[1]) {
        const hours = parseInt(match[1]);
        dueAt = new Date(now.getTime() + hours * 60 * 60 * 1000);
      }
      title = input.replace(new RegExp(inHoursRegex, 'i'), '').trim();
      confidenceScore = 0.9;
    }

    // Clean up title (remove double spaces, ending prepositions)
    title = title.replace(/\s+at\s*$/i, '').trim();

    // Check for urgent keywords to escalate priority
    if (lowerInput.includes('urgent') || lowerInput.includes('asap') || lowerInput.includes('important')) {
      priority = 'high';
    }

    return {
      title: title || input,
      dueAt,
      priority,
      reminderMode: 'smart',
      confidenceScore
    };
  }

  static async generateSubtasksFromNotes(notes: string): Promise<string[]> {
    return new Promise((resolve) => {
      const pythonScript = path.join(__dirname, 'extract_subtasks.py');
      const escapedNotes = notes.replace(/"/g, '\\"');
      
      exec(`python "${pythonScript}" "${escapedNotes}"`, (error, stdout, stderr) => {
        if (error) {
          console.error(`[AI Subtask Extractor] Error executing python script: ${error.message}`);
          console.error(`[AI Subtask Extractor] stderr: ${stderr}`);
          resolve(AiService.generateSubtasksRuleEngine(notes));
          return;
        }

        try {
          const parsedOutput = JSON.parse(stdout.trim());
          if (Array.isArray(parsedOutput)) {
            resolve(parsedOutput);
            return;
          }
        } catch (parseError) {
          console.error(`[AI Subtask Extractor] Failed parsing LLM output: ${parseError}`);
          console.error(`[AI Subtask Extractor] Raw output: ${stdout}`);
        }

        resolve(AiService.generateSubtasksRuleEngine(notes));
      });
    });
  }

  static generateSubtasksRuleEngine(notes: string): string[] {
    const subtasks: string[] = [];
    const lines = notes.split(/\r?\n/);
    for (const line of lines) {
      let cleaned = line.trim();
      if (!cleaned) continue;
      if (cleaned.startsWith('-') || cleaned.startsWith('*') || cleaned.startsWith('•')) {
        cleaned = cleaned.substring(1).trim();
      }
      if (cleaned) {
        subtasks.push(cleaned);
      }
    }
    if (subtasks.length === 0) {
      return ['Define final outcome', 'Gather necessary tools', 'Execute task core steps', 'Review results'];
    }
    return subtasks;
  }

  /**
   * Generates a subtask checklist for large tasks.
   * Leverages mock steps for immediate responsiveness with optional OpenAI override.
   */
  static generateSubtasks(title: string): string[] {
    const lowerTitle = title.toLowerCase();

    // Deterministic templates based on topic
    if (lowerTitle.includes('report') || lowerTitle.includes('assignment') || lowerTitle.includes('paper')) {
      return ['Research & gather information', 'Outline key sections', 'Write first draft', 'Review and proofread', 'Final submission'];
    }
    if (lowerTitle.includes('study') || lowerTitle.includes('learn') || lowerTitle.includes('read')) {
      return ['Skim chapter content', 'Take notes on major concepts', 'Create study flashcards', 'Complete review questions'];
    }
    if (lowerTitle.includes('workout') || lowerTitle.includes('gym') || lowerTitle.includes('exercise')) {
      return ['Warm up (5-10 min)', 'Target routine exercises', 'Cool down stretching', 'Log progress'];
    }
    if (lowerTitle.includes('clean') || lowerTitle.includes('laundry') || lowerTitle.includes('room')) {
      return ['Gather supplies', 'Sort and tidy items', 'Wipe down surfaces', 'Organize final space'];
    }

    // Fallback general steps
    return ['Define final outcome', 'Gather necessary tools', 'Execute task core steps', 'Review results'];
  }
}
