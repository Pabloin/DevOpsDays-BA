import { useState, useRef, useEffect } from 'react';

const SERVICE_NAME = '${{ values.service_name }}';

export default function App() {
  const [messages, setMessages] = useState([
    { role: 'assistant', content: `Hi! I'm ${SERVICE_NAME}. How can I help you today?` },
  ]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const bottomRef = useRef(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  async function sendMessage() {
    if (!input.trim() || loading) return;

    const userMessage = { role: 'user', content: input.trim() };
    const updatedMessages = [...messages, userMessage];
    setMessages(updatedMessages);
    setInput('');
    setLoading(true);

    // Add empty assistant message to stream into
    setMessages(prev => [...prev, { role: 'assistant', content: '' }]);

    try {
      const response = await fetch('/api/chat/stream', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          // Claude requires first message to be 'user' — strip leading assistant greeting
          messages: updatedMessages
            .slice(updatedMessages.findIndex(m => m.role === 'user'))
            .map(m => ({ role: m.role, content: m.content })),
        }),
      });

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop();

        for (const line of lines) {
          if (!line.startsWith('data: ')) continue;
          const data = line.slice(6);
          if (data === '[DONE]') break;
          try {
            const { text, error } = JSON.parse(data);
            if (error) throw new Error(error);
            if (text) {
              setMessages(prev => {
                const updated = [...prev];
                updated[updated.length - 1] = {
                  ...updated[updated.length - 1],
                  content: updated[updated.length - 1].content + text,
                };
                return updated;
              });
            }
          } catch {}
        }
      }
    } catch (err) {
      setMessages(prev => {
        const updated = [...prev];
        updated[updated.length - 1] = { role: 'assistant', content: `Error: ${err.message}` };
        return updated;
      });
    } finally {
      setLoading(false);
    }
  }

  function handleKeyDown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  }

  return (
    <div className="app">
      <header className="header">
        <span className="header-icon">🤖</span>
        <span className="header-title">{SERVICE_NAME}</span>
        <span className="header-sub">Powered by AWS Bedrock</span>
      </header>

      <div className="messages">
        {messages.map((msg, i) => (
          <div key={i} className={`message ${msg.role}`}>
            <div className="bubble">
              {msg.content || <span className="cursor">▌</span>}
            </div>
          </div>
        ))}
        <div ref={bottomRef} />
      </div>

      <div className="input-area">
        <textarea
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Ask anything… (Enter to send, Shift+Enter for newline)"
          disabled={loading}
          rows={2}
        />
        <button onClick={sendMessage} disabled={loading || !input.trim()}>
          {loading ? '…' : 'Send'}
        </button>
      </div>
    </div>
  );
}
