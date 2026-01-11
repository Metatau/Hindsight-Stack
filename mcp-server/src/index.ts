#!/usr/bin/env node
/**
 * Hindsight MCP Server for Claude Code
 *
 * Provides long-term memory capabilities through Hindsight API:
 * - retain: Save information to memory
 * - recall: Retrieve information from memory
 * - reflect: Analyze memories and form insights
 *
 * @author MONO Studio
 * @license MIT
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";

// Configuration
const HINDSIGHT_URL = process.env.HINDSIGHT_URL || "http://localhost:8888";
const DEFAULT_BANK_ID = process.env.MEMORY_BANK_ID || "claude-code-memory";
const API_VERSION = "v1";
const NAMESPACE = "default";

// Tool definitions
const tools: Tool[] = [
  {
    name: "memory_retain",
    description: `Сохранить информацию в долгосрочную память AI-агента.

Используй для запоминания:
- Предпочтений пользователя (языки, стили кода, инструменты)
- Важных решений и их обоснований
- Контекста проектов и архитектуры
- Паттернов и best practices из кодовой базы
- Ошибок и их решений`,
    inputSchema: {
      type: "object",
      properties: {
        content: {
          type: "string",
          description: "Информация для сохранения в память"
        },
        context: {
          type: "string",
          description: "Дополнительный контекст (проект, файл, тема)"
        },
        bank_id: {
          type: "string",
          description: `ID банка памяти (по умолчанию: ${DEFAULT_BANK_ID})`
        }
      },
      required: ["content"]
    }
  },
  {
    name: "memory_recall",
    description: `Вспомнить информацию из долгосрочной памяти.

Hindsight использует 4 стратегии поиска параллельно:
- Semantic: Поиск по смыслу (vector similarity)
- Keyword: Точное совпадение ключевых слов (BM25)
- Graph: Связи между сущностями
- Temporal: Фильтрация по времени

Используй для:
- Получения контекста о проекте/пользователе
- Поиска предыдущих решений похожих проблем
- Восстановления архитектурных решений`,
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "Запрос для поиска в памяти"
        },
        limit: {
          type: "number",
          description: "Максимальное количество результатов (по умолчанию 5)"
        },
        bank_id: {
          type: "string",
          description: `ID банка памяти (по умолчанию: ${DEFAULT_BANK_ID})`
        }
      },
      required: ["query"]
    }
  },
  {
    name: "memory_reflect",
    description: `Проанализировать существующие воспоминания и сформировать выводы.

Reflect позволяет:
- Формировать мнения на основе накопленного опыта
- Выявлять паттерны в поведении и предпочтениях
- Создавать обобщения из отдельных фактов
- Формировать рекомендации на основе истории

Используй для:
- Понимания общих предпочтений пользователя
- Анализа часто возникающих проблем
- Формирования best practices на основе опыта`,
    inputSchema: {
      type: "object",
      properties: {
        topic: {
          type: "string",
          description: "Тема для анализа и рефлексии"
        },
        bank_id: {
          type: "string",
          description: `ID банка памяти (по умолчанию: ${DEFAULT_BANK_ID})`
        }
      },
      required: ["topic"]
    }
  }
];

// Helper function for API calls
async function hindsightRequest(
  method: string,
  endpoint: string,
  body?: Record<string, unknown>
): Promise<unknown> {
  const url = `${HINDSIGHT_URL}/${API_VERSION}/${NAMESPACE}${endpoint}`;

  const options: RequestInit = {
    method,
    headers: {
      "Content-Type": "application/json",
    },
  };

  if (body) {
    options.body = JSON.stringify(body);
  }

  const response = await fetch(url, options);

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Hindsight API error: ${response.status} - ${errorText}`);
  }

  return response.json();
}

// Create MCP server
const server = new Server(
  {
    name: "hindsight-memory",
    version: "2.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Handle tool listing
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools,
}));

// Handle tool execution
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "memory_retain": {
        const bankId = (args?.bank_id as string) || DEFAULT_BANK_ID;
        const content = args?.content as string;
        const context = args?.context as string | undefined;

        // Build the item
        const item: Record<string, unknown> = { content };
        if (context) {
          item.context = context;
        }

        const result = await hindsightRequest(
          "POST",
          `/banks/${bankId}/memories`,
          {
            items: [item],
            async: false
          }
        );

        return {
          content: [
            {
              type: "text",
              text: `✅ Сохранено в память (bank: ${bankId}):\n${JSON.stringify(result, null, 2)}`,
            },
          ],
        };
      }

      case "memory_recall": {
        const bankId = (args?.bank_id as string) || DEFAULT_BANK_ID;
        const query = args?.query as string;
        const limit = (args?.limit as number) || 5;

        const result = await hindsightRequest(
          "POST",
          `/banks/${bankId}/memories/recall`,
          {
            query,
            limit
          }
        );

        // Format results for better readability
        const response = result as { results?: Array<{ text: string; entities?: string[] }> };
        if (response.results && response.results.length > 0) {
          const formatted = response.results.map((r, i) =>
            `${i + 1}. ${r.text}${r.entities ? ` [${r.entities.join(", ")}]` : ""}`
          ).join("\n\n");

          return {
            content: [
              {
                type: "text",
                text: `🔍 Найдено ${response.results.length} записей (bank: ${bankId}):\n\n${formatted}`,
              },
            ],
          };
        }

        return {
          content: [
            {
              type: "text",
              text: `🔍 Ничего не найдено в памяти по запросу: "${query}"`,
            },
          ],
        };
      }

      case "memory_reflect": {
        const bankId = (args?.bank_id as string) || DEFAULT_BANK_ID;
        const topic = args?.topic as string;

        const result = await hindsightRequest(
          "POST",
          `/banks/${bankId}/reflect`,
          {
            topic
          }
        );

        return {
          content: [
            {
              type: "text",
              text: `💭 Анализ памяти по теме "${topic}":\n${JSON.stringify(result, null, 2)}`,
            },
          ],
        };
      }

      default:
        return {
          content: [
            {
              type: "text",
              text: `❌ Неизвестный инструмент: ${name}`,
            },
          ],
          isError: true,
        };
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    return {
      content: [
        {
          type: "text",
          text: `❌ Ошибка Hindsight: ${errorMessage}\n\nУбедитесь, что Hindsight запущен. Выполните ./scripts/start.sh в директории hindsight-stack`,
        },
      ],
      isError: true,
    };
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Hindsight MCP Server v2.0 started");
  console.error(`API: ${HINDSIGHT_URL}/${API_VERSION}/${NAMESPACE}`);
  console.error(`Default bank: ${DEFAULT_BANK_ID}`);
}

main().catch((error) => {
  console.error("Failed to start server:", error);
  process.exit(1);
});
