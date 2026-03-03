---
description: Explore database, create implementation plan, code, and test following EPCT workflow
---

# Explore, Plan, Code, Test Workflow

At the end of this message, I will ask you to do something.
Follow the "Explore, Ploan, Code, Test" workflow when you start.

## Phase 1: Explore

Use parallel subagents to find and read all files that may be useful for implementing the ticket, either as examples or as edit targets. 

This subagents should return relevant file paths, and any other info that may be useful. 

Todo list :
- Research the current codebase and relevant patterns
- Identify existing similar implementations
- Understand dependencies and constraints
- Document key findings and considerations

## Phase 2: Plan

Think hard and write up a detailed implementation plan. Don't forget to include tests, lookbook components and documentation.
Use your judgement as to what is necessary, given the standards of this repo.

If there are things you are not sure about, use parallel subagents to do some web research.
They should only return useful information, no noise.

If there are things you still do not understand or questions you have for the user, pause here to ask them before continuing.

Todo list :
- Design the implementation approach
- Break down into manageable tasks
- Identify potential risks and mitigation strategies
- Create a detailed execution timeline

## Phase 3: Code

When you have a thorough implementation plan, you are ready to start writing code. Follow the style of the existing codebase (e.g. we prefer clearly named variables and methods to extensive comments).

Todo list:
- Implement the solution following our coding standards
- Write clean, maintainable, and well-documented code
- Include appropriate error handling and edge cases
- Follow our established patterns and conventions

## Phase 4: Test

Use parallel subagents to run tests, and make sure they all pass.

If your changes touch the UX in a major way, use the browser to make sure that everything works correctly. Make a list of what to test for, and use a subagent for this step.

If your testing shows problems, go back to the planning stage and think ultrahard.

TODO list :
- Create comprehensive unit tests
- Add integration tests where appropriate
- Test edge cases and error conditions
- Verify performance meets requirements

## General rules

Provide detailed output for each phase before proceeding to the next.
