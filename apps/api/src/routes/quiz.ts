import type { FastifyInstance } from "fastify";
import {
  type QuizGenerateRequest,
  type QuizInstance,
  type QuizSubmitRequest,
  type QuizSubmitResponse,
} from "@owlnighter/contracts";
import type { Deps } from "../deps.js";
import { requireUser } from "../plugins/auth.js";
import { badRequest } from "../plugins/errors.js";
import { generateStepQuiz, submitQuiz } from "../services/quiz.js";
import { register } from "./helpers.js";

export function registerQuizRoutes(app: FastifyInstance, deps: Deps): void {
  register<QuizGenerateRequest, QuizInstance>(app, deps, "generateStepQuiz", async ({ req, body, params }) => {
    const user = requireUser(req);
    const stepId = params["id"];
    if (!stepId) throw badRequest("Missing step id.");
    return generateStepQuiz(deps, user, stepId, body);
  });

  register<QuizSubmitRequest, QuizSubmitResponse>(app, deps, "submitQuiz", async ({ req, body, params }) => {
    const user = requireUser(req);
    const quizId = params["id"];
    if (!quizId) throw badRequest("Missing quiz id.");
    return submitQuiz(deps, user, quizId, body);
  });
}
