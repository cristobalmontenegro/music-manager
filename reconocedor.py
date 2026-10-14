import acoustid
import sys

# Tu API Key de AcoustID (puedes usar esta de prueba o generar una gratis en su web)
API_KEY = 'cSpUJKpD'

def find_music_id(file_path):
    try:
        # fpcalc se usa internamente para obtener la duración y la huella
        results = acoustid.match(API_KEY, file_path, parse=False)
        
        # De todos los resultados, buscamos el que tenga la puntuación más alta
        best_score = 0
        best_id = None
        
        if results and 'results' in results:
            for result in results['results']:
                if 'score' in result and result['score'] > best_score:
                    best_score = result['score']
                    # Devolvemos el ID de la grabación, que es único para una canción
                    if 'recordings' in result and result['recordings']:
                        best_id = result['recordings'][0]['id']

        if best_id:
            print(best_id)
        else:
            # Si no encuentra nada, imprime la huella del archivo como fallback
            duration, fingerprint = acoustid.fingerprint_file(file_path)
            print(f"local:{fingerprint.decode('utf-8')}")

    except Exception as e:
        # Si el archivo está dañado o hay un error, no devuelve nada
        pass

if __name__ == "__main__":
    if len(sys.argv) > 1:
        find_music_id(sys.argv[1])
