import Vision
import Quartz
import Cocoa
import objc
from Foundation import NSURL

def recognize_text(image_path):
    # Load image
    input_url = NSURL.fileURLWithPath_(image_path)
    
    # Create request handler
    handler = Vision.VNImageRequestHandler.alloc().initWithURL_options_(input_url, None)
    
    # Define the request
    results = []
    def completion_handler(request, error):
        if error:
            print(f"Error: {error}")
            return
        observations = request.results()
        for observation in observations:
            # Get the top candidate
            top_candidate = observation.topCandidates_(1)[0]
            text = top_candidate.string()
            # Convert normalized coordinates to pixel coordinates
            # Note: Vision uses bottom-left origin
            bbox = observation.boundingBox()
            results.append({
                "text": text,
                "confidence": top_candidate.confidence(),
                "bbox": [bbox.origin.x, bbox.origin.y, bbox.size.width, bbox.size.height]
            })

    request = Vision.VNRecognizeTextRequest.alloc().initWithCompletionHandler_(completion_handler)
    request.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)
    
    # Perform request
    success, error = handler.performRequests_error_([request], None)
    
    return results

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python3 apple_vision.py <image_path>")
        sys.exit(1)
    
    image_path = sys.argv[1]
    text_data = recognize_text(image_path)
    for entry in text_data:
        print(f"[{entry['confidence']:.2f}] {entry['text']} at {entry['bbox']}")
