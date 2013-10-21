CC=ghc
flags=-O2

default: 
	$(CC) $(flags) src/Data/Image.hs

haddock: src/Data/*.hs src/Data/Image/*.hs
	rm haddock -rf
	mkdir haddock
	haddock -h -o haddock/ src/Data/*.hs src/Data/Image/*.hs

clean:
	rm src/Data/*.o src/Data/*.hi src/Data/Image/*.o src/Data/Image/*.hi