import { useState, useEffect, useRef } from "react";
import { formatTimeInMinutes } from "../../utilities/time";
import { io, Socket } from "socket.io-client";

const socketUrl = import.meta.env.VITE_SOCKET_URL;

function HomePage() {
  const [recordingStatus, setRecordingStatus] = useState<number>(0); // 0 - can start, 1 - recording, 2 - on pause
  const [recordingLength, setRecordingLength] = useState<number>(0); // in seconds

  const [transcript, setTranscript] = useState<string>("");
  const [summary, setSummary] = useState<string>("");
  const [socket, setSocket] = useState<Socket | null>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const audioStreamRef = useRef<MediaStream | null>(null);
  const audioChunksRef = useRef<BlobPart[] | null>(null);

  const [isLoading, setIsLoading] = useState<boolean>(false);

  // Fallback function if AudioWorklet isn't supported
  const setupMediaRecorderOnly = (stream: MediaStream) => {
    if (socket == null) return;

    const audioChunks: BlobPart[] = [];
    mediaRecorderRef.current = new MediaRecorder(stream, {
      mimeType: "audio/webm;codecs=opus",
    });

    mediaRecorderRef.current.ondataavailable = (event: BlobEvent) => {
      if (event.data.size > 0) {
        audioChunks.push(event.data);
      }
    };

    mediaRecorderRef.current.start(10);
    setRecordingStatus(1);

    // Save audioChunks so handleStop can use it
    audioChunksRef.current = audioChunks;
  };

  const handleStart = async () => {
    if (socket == null) return;

    try {
      setTranscript("");
      setSummary("");
      const audioChunks: BlobPart[] = []; // Store chunks locally during recording

      // Get audio stream
      const stream: MediaStream = await navigator.mediaDevices.getUserMedia({
        audio: true,
      });
      audioStreamRef.current = stream;

      audioContextRef.current = new (window.AudioContext ||
        (window as any).webkitAudioContext)();

      // Load the audio processor worklet
      try {
        await audioContextRef.current.audioWorklet.addModule(
          "/audio-processor.js"
        );
      } catch (error) {
        console.error("Failed to load audio processor:", error);
        // Fallback to MediaRecorder only if worklet fails
        return setupMediaRecorderOnly(stream);
      }

      const source: MediaStreamAudioSourceNode =
        audioContextRef.current.createMediaStreamSource(stream);
      const processor: AudioWorkletNode = new AudioWorkletNode(
        audioContextRef.current,
        "audio-processor"
      );

      // processor.port.onmessage = (event) => {
      //   const audioData = event.data.audioData;
      // };

      source.connect(processor);
      processor.connect(audioContextRef.current.destination);

      mediaRecorderRef.current = new MediaRecorder(stream);
      mediaRecorderRef.current.ondataavailable = (event: BlobEvent) => {
        if (event.data.size > 0) {
          audioChunks.push(event.data);
        }
      };

      // Store the audio chunks array in the ref so it's accessible in handleStop
      audioChunksRef.current = audioChunks;

      mediaRecorderRef.current.start(10);
      setRecordingStatus(1);
    } catch (error) {
      setRecordingStatus(0);
      console.error("Error accessing microphone:", error);
    }
  };

  const handleStop = () => {
    if (socket == null) return;

    if (mediaRecorderRef.current) {
      // Request the final data
      mediaRecorderRef.current.requestData();

      // Wait for the last ondataavailable event to fire
      setTimeout(() => {
        if (audioChunksRef.current && audioChunksRef.current.length > 0) {
          setIsLoading(true);

          // Combine all chunks into a single Blob
          const audioBlob = new Blob(audioChunksRef.current, {
            type: "audio/webm",
          });

          // Send the complete audio to backend via Socket
          socket.emit("audio:send", audioBlob);

          // Clear the chunks
          audioChunksRef.current = [];
        }

        if (mediaRecorderRef.current) {
          mediaRecorderRef.current.stop();
        }
      }, 100); // Small delay to ensure last chunk is captured
    }

    if (audioStreamRef.current) {
      audioStreamRef.current.getTracks().forEach((track) => track.stop());
    }
    if (audioContextRef.current) {
      audioContextRef.current.close();
    }
    setRecordingStatus(0);
    setRecordingLength(0);
  };

  useEffect(() => {
    const intervalSeconds = setInterval(() => {
      if (recordingStatus !== 1) return;
      setRecordingLength((prevLength) => prevLength + 1);
    }, 1000);

    return () => clearInterval(intervalSeconds);
  }, [recordingStatus]);

  useEffect(() => {
    // Initialize WebSocket connection
    const newSocket = io(socketUrl);
    setSocket(newSocket);

    // Listen for transcription results
    newSocket.on("transcription:received", (data) => {
      setTranscript((prev) => prev + " " + data.text);
    });

    newSocket.on("summary:received", (data) => {
      setSummary((prev) => prev + " " + data.text);
      setIsLoading(false);
    });

    return () => {
      newSocket.disconnect();

      if (mediaRecorderRef.current) {
        mediaRecorderRef.current.stop();
      }
      if (audioStreamRef.current) {
        audioStreamRef.current.getTracks().forEach((track) => track.stop());
      }
      if (audioContextRef.current) {
        audioContextRef.current.close();
      }
    };
  }, []);

  useEffect(() => {
    // Limit because of Kafka
    if (recordingLength >= 35) {
      handleStop();
    }
  }, [recordingLength]);

  return (
    <div className="min-w-screen min-h-screen bg-gray-50 flex flex-col justify-center items-center p-6 gap-8">
      <div>
        <h1 className="text-4xl font-extrabold text-blue-700 tracking-tight">
          Welcome to MediScribe!
        </h1>
      </div>

      <div className="flex flex-row gap-6">
        {recordingStatus === 0 && (
          <button
            onClick={handleStart}
            className="px-6 py-2 rounded-xl bg-green-500 text-white font-medium transition
             hover:bg-green-600 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-green-500"
            disabled={isLoading}
          >
            Start Recording
          </button>
        )}
        {recordingStatus !== 0 && (
          <button
            onClick={handleStop}
            className="px-6 py-2 rounded-xl bg-red-500 text-white font-medium hover:bg-red-600 transition"
          >
            Stop Recording
          </button>
        )}
      </div>

      <div className="text-lg text-gray-700 font-medium flex flex-col justify-center items-center ">
        <p className="font-semibold">
          Time: {formatTimeInMinutes(recordingLength)}
        </p>
        {recordingLength >= 25 && (
          <p>
            Recording limit: 35 seconds. Auto-stopping in {35 - recordingLength}{" "}
            seconds.
          </p>
        )}
      </div>

      {transcript.length > 0 && (
        <div className="w-full max-w-3xl bg-white shadow-md rounded-xl p-6 space-y-4">
          <h2 className="text-2xl font-semibold text-blue-700">Transcript:</h2>
          <p className="text-gray-700 whitespace-pre-line">{transcript}</p>
        </div>
      )}

      {summary.length > 0 && (
        <div className="w-full max-w-3xl bg-white shadow-md rounded-xl p-6 space-y-4">
          <h2 className="text-2xl font-semibold text-blue-700">Summary:</h2>
          {summary
            .split(/\*\*(.*?)\*\*/g)
            .filter(Boolean)
            .map((section, idx) => {
              const trimmedSection = section.trim();

              if (idx % 2 === 0) {
                const lines = trimmedSection
                  .split("\n")
                  .map((line) => line.trim())
                  .filter(Boolean);

                if (lines.length > 1) {
                  return (
                    <>
                      {lines.map((line, i) => (
                        <p key={i}>{line}</p>
                      ))}
                    </>
                  );
                }

                return <p key={idx}>{trimmedSection}</p>;
              }

              return (
                <p
                  key={idx}
                  className="text-lg font-semibold text-gray-700 mt-4"
                >
                  {trimmedSection}
                </p>
              );
            })}
        </div>
      )}

      {isLoading && transcript.length == 0 && "Processing transcription..."}
      {isLoading &&
        transcript.length > 0 &&
        summary.length == 0 &&
        "Processing summary..."}
    </div>
  );
}

export default HomePage;
