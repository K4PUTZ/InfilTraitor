import speech_recognition as sr
import sys

def listen():
    r = sr.Recognizer()
    with sr.Microphone() as source:
        print("Adjusting for ambient noise... Please be quiet for a moment.")
        r.adjust_for_ambient_noise(source, duration=1)
        print("I am listening, sir...")
        try:
            audio = r.listen(source, timeout=5, phrase_time_limit=10)
            print("Processing your request...")
            text = r.recognize_google(audio)
            print(f"I heard: {text}")
            return text
        except sr.WaitTimeoutError:
            return None
        except sr.UnknownValueError:
            return None
        except sr.RequestError as e:
            return None

if __name__ == "__main__":
    listen()
