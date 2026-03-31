'''import serial
import time

PORT = 'COM6'
BAUD = 460800
FILENAME = "C:/Users/dayes/verilog/CNN_1/Reference code/cnn_verilog/data/6_0.txt"

def load_hex_file(filename):
    with open(filename, 'r') as f:
        hex_strs = f.read().split()
        data = [int(h, 16) for h in hex_strs]
    assert len(data) == 784, f"Expected 784 bytes, got {len(data)}"
    return data  # 리스트로 반환

def main():
    data = load_hex_file(FILENAME)
    ser = serial.Serial(PORT, baudrate=BAUD)
    
    try:
        print(f"Sending {len(data)} bytes one-by-one to {PORT}...")

        start = time.perf_counter()

        for i, byte in enumerate(data):
            ser.write(bytes([byte]))  # 한 바이트씩 전송
            time.sleep(0.1)  # 1ms 지연, 필요에 따라 조절 (예: 0.0005)

        elapsed = (time.perf_counter() - start) * 1000
        print(f"Done! Sent in {elapsed:.3f} ms")

    finally:
        ser.close()

if __name__ == '__main__':
    main()
'''
import serial
import time
import serial.tools.list_ports

PORT = 'COM6'
BAUD = 460800
# FILENAME 경로를 사용자 환경에 맞게 유지합니다.
FILENAME = "C:/Users/dayes/verilog/CNN_1/Reference code/cnn_verilog/data/6_0.txt"

def load_hex_file(filename):
    """Hex 파일에서 784바이트 데이터를 읽어 리스트로 반환합니다."""
    try:
        with open(filename, 'r') as f:
            hex_strs = f.read().split()
            # 데이터는 리스트 형태로 int로 저장됩니다.
            data = [int(h, 16) for h in hex_strs] 
        assert len(data) == 784, f"Error: Expected 784 bytes, got {len(data)}"
        return data
    except FileNotFoundError:
        print(f"Error: File not found at {filename}")
        return []
    except Exception as e:
        print(f"Error loading file: {e}")
        return []

def main():
    data_to_send = load_hex_file(FILENAME)
    if not data_to_send:
        return

    # 전송된 데이터 리스트를 문자열로 저장하여 나중에 출력합니다.
    tx_hex_list = [f'{b:02X}' for b in data_to_send]
    
    try:
        # timeout=None (기본값) 또는 timeout을 생략하여 무한 대기 설정
        with serial.Serial(PORT, baudrate=BAUD) as ser: # timeout 설정 제거
            print(f"--- Serial Port Opened {PORT} @ {BAUD} ---")
            print(f"[TX] Start sending {len(data_to_send)} bytes (1ms throttle)...")
            
            start = time.perf_counter()

            # 1ms 지연을 주면서 한 바이트씩 전송
            for byte in data_to_send:
                ser.write(bytes([byte]))
    
            elapsed = (time.perf_counter() - start) * 1000
            print(f"[TX] Done! Sent in {elapsed:.2f} ms")

            # -----------------------------------------------
            # 1. 보낸 값 출력
            # -----------------------------------------------
            print("\n[TX] Transmitted Data (HEX):")
            # 16바이트씩 줄바꿈하여 가독성을 높입니다.
            for i in range(0, len(tx_hex_list), 16):
                print(' '.join(tx_hex_list[i:i+16]))
            
            print("-----------------------------------------------")

            # -----------------------------------------------
            # 2. 수신 값 대기 및 출력
            # -----------------------------------------------
            print(f"[RX] Waiting for response (NO TIMEOUT - Will block indefinitely if no data arrives)...")
            
            # timeout 설정 없이 무한정 기다림
            # ser.read(784)를 호출합니다.
            received = ser.read(784) 

            if len(received) == 784:
                print(f"[RX] Received all 784 bytes successfully.")
            else:
                # 무한 대기 설정에서는 이 메시지가 나타나기 전에 프로그램이 멈출 수 있습니다.
                print(f"[RX] Incomplete! Only {len(received)} bytes received.")

            rx_hex_list = [f'{b:02X}' for b in received]
            
            print("\n[RX] Received Data (HEX):")
            for i in range(0, len(rx_hex_list), 16):
                print(' '.join(rx_hex_list[i:i+16]))
            print("-----------------------------------------------")


    except serial.SerialException as e:
        print(f"Serial Error: Could not open port {PORT}. Please check connection. {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == '__main__':
    main()
