import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import {
  BedrockRuntimeClient,
  InvokeModelCommand,
  InvokeModelWithResponseStreamCommand,
} from '@aws-sdk/client-bedrock-runtime';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Read system prompt from prompt.md at startup
const promptPath = path.join(__dirname, '..', 'prompt.md');
const SYSTEM_PROMPT = fs.readFileSync(promptPath, 'utf-8').trim();
console.log('Loaded system prompt from prompt.md');

const MODEL_ID = process.env.BEDROCK_MODEL_ID || 'anthropic.claude-3-haiku-20240307-v1:0';
const AWS_REGION = process.env.AWS_REGION || 'us-east-1';
const PORT = process.env.PORT || 3001;

const bedrock = new BedrockRuntimeClient({ region: AWS_REGION });

const app = express();
app.use(cors());
app.use(express.json());

// Build request body based on model provider
function buildRequestBody(messages, stream = false) {
  const isAnthropic = MODEL_ID.startsWith('anthropic.');
  const isNova = MODEL_ID.startsWith('amazon.nova');

  if (isAnthropic) {
    return {
      anthropic_version: 'bedrock-2023-05-31',
      max_tokens: 1024,
      system: SYSTEM_PROMPT,
      messages,
    };
  }

  if (isNova) {
    return {
      system: [{ text: SYSTEM_PROMPT }],
      messages: messages.map(m => ({ role: m.role, content: [{ text: m.content }] })),
      inferenceConfig: { max_new_tokens: 1024 },
    };
  }

  // Generic fallback
  return { inputText: messages.at(-1).content };
}

// Extract text from response body based on model
function extractText(responseBody) {
  if (responseBody.content?.[0]?.text) return responseBody.content[0].text; // Anthropic
  if (responseBody.output?.message?.content?.[0]?.text) return responseBody.output.message.content[0].text; // Nova
  return JSON.stringify(responseBody);
}

// POST /api/chat — full response
app.post('/api/chat', async (req, res) => {
  const { messages } = req.body;
  try {
    const body = buildRequestBody(messages);
    const command = new InvokeModelCommand({
      modelId: MODEL_ID,
      contentType: 'application/json',
      accept: 'application/json',
      body: JSON.stringify(body),
    });
    const response = await bedrock.send(command);
    const responseBody = JSON.parse(new TextDecoder().decode(response.body));
    res.json({ message: extractText(responseBody) });
  } catch (err) {
    console.error('Bedrock error:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/chat/stream — server-sent events
app.post('/api/chat/stream', async (req, res) => {
  const { messages } = req.body;

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  try {
    const body = buildRequestBody(messages, true);
    const command = new InvokeModelWithResponseStreamCommand({
      modelId: MODEL_ID,
      contentType: 'application/json',
      accept: 'application/json',
      body: JSON.stringify(body),
    });
    const response = await bedrock.send(command);

    for await (const event of response.body) {
      if (event.chunk?.bytes) {
        const chunk = JSON.parse(new TextDecoder().decode(event.chunk.bytes));
        // Anthropic delta
        if (chunk.type === 'content_block_delta' && chunk.delta?.text) {
          res.write(`data: ${JSON.stringify({ text: chunk.delta.text })}\n\n`);
        }
        // Nova delta
        if (chunk.contentBlockDelta?.delta?.text) {
          res.write(`data: ${JSON.stringify({ text: chunk.contentBlockDelta.delta.text })}\n\n`);
        }
      }
    }
    res.write('data: [DONE]\n\n');
  } catch (err) {
    console.error('Bedrock stream error:', err);
    res.write(`data: ${JSON.stringify({ error: err.message })}\n\n`);
  } finally {
    res.end();
  }
});

app.listen(PORT, () => {
  console.log(`AI Ops Assistant backend running on port ${PORT}`);
  console.log(`Model: ${MODEL_ID} | Region: ${AWS_REGION}`);
});
