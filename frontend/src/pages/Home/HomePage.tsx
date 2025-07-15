import { useState, useEffect, useRef } from "react";
import { formatTimeInMinutes } from "../../utilities/time";

function HomePage() {
  const socketRef = useRef<WebSocket | null>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const [recordingStatus, setRecordingStatus] = useState<number>(0); // 0 - can start, 1 - recording, 2 - on pause
  const [recordingLength, setRecordingLength] = useState<number>(0); // in seconds

  const handleStart = async () => {
    if (!socketRef.current) return;
    if (!mediaRecorderRef.current) return;

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    socketRef.current = new WebSocket("ws://localhost:4000");

    mediaRecorderRef.current = new MediaRecorder(stream);
    mediaRecorderRef.current.ondataavailable = (event) => {
      if (
        socketRef.current != null &&
        socketRef.current.readyState === WebSocket.OPEN
      ) {
        socketRef.current.send(event.data);
      }
    };
    mediaRecorderRef.current.start(1000); // send chunks every second
    setRecordingStatus(1);
  };

  const handleStop = () => {
    if (!socketRef.current) return;
    if (!mediaRecorderRef.current) return;

    mediaRecorderRef.current.stop();
    socketRef.current.close();
    setRecordingStatus(0);
    setRecordingLength(0);
  };

  const handlePause = () => {
    if (
      mediaRecorderRef.current &&
      mediaRecorderRef.current.state === "recording"
    ) {
      mediaRecorderRef.current.pause();
      setRecordingStatus(2);
    }
  };

  const handleResume = () => {
    if (
      mediaRecorderRef.current &&
      mediaRecorderRef.current.state === "paused"
    ) {
      mediaRecorderRef.current.resume();
      setRecordingStatus(1);
    }
  };

  useEffect(() => {
    const intervalSeconds = setInterval(() => {
      if (recordingStatus !== 1) return;
      setRecordingLength((prevLength) => prevLength + 1);
    }, 1000);

    return () => clearInterval(intervalSeconds);
  }, [recordingStatus]);

  return (
    <div className="w-screen h-screen flex flex-col justify-center items-center gap-5">
      <div>
        <p className="text-3xl font-bold text-blue-600">
          Welcome to MediScribe!
        </p>
      </div>
      <div className="flex flex-row gap-10">
        {recordingStatus == 0 && (
          <button onClick={handleStart}>Start recording</button>
        )}
        {recordingStatus != 0 && (
          <button onClick={handleStop}>Stop recording</button>
        )}
        {recordingStatus == 1 && (
          <button onClick={handlePause}>Pause recording</button>
        )}
        {recordingStatus == 2 && (
          <button onClick={handleResume}>Resume recording</button>
        )}
      </div>

      <div className="">Time: {formatTimeInMinutes(recordingLength)}</div>
    </div>
  );
}

export default HomePage;
