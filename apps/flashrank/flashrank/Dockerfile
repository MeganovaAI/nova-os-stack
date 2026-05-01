FROM python:3.11-slim
RUN pip install --no-cache-dir flashrank fastapi uvicorn
WORKDIR /app
COPY server.py /app/server.py
EXPOSE 8000
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
