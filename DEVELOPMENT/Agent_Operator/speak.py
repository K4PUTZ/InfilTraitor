import subprocess
import sys

def speak(text):
    # -v Daniel: The butler voice
    # -r 150: Slightly slower, more deliberate pace ( butler-like)
    subprocess.run(['say', '-v', 'Daniel', '-r', '160', text])

if __name__ == "__main__":
    if len(sys.argv) > 1:
        speak(" ".join(sys.argv[1:]))
