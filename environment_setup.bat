@echo off
REM Set up backend environment
cd backend
copy .env.template .env
cd ..

REM Set up frontend environment
cd frontend
copy .env.template .env
cd ..

REM Set up summarizer environment
set /p TOKEN=Enter your openai token: 
cd worker\summarizer
echo OPENAI_API_KEY=%TOKEN%>>.env
cd ..\..\

echo .env files copied successfully.