--    The University of New Mexico's Haskell Image Processing Library
--    Copyright (C) 2013 Joseph Collard
--
--    This program is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with this program.  If not, see <http://www.gnu.org/licenses/>.

module Data.Image.Interactive(display, 
                              setDisplayProgram,
                              plotHistograms) where

import Data.Image.IO
import Data.Image.Binary(areas)
import Data.Image.Internal

--base>=4
import Data.List(intercalate)
import Data.IORef
import System.IO.Unsafe
import System.IO

--vector>=0.10.0.2
import qualified Data.Vector.Unboxed as V

--process>=1.1.0.2
import System.Process

{-| Sets the program to use when making a call to display and specifies if
    the program can accept an image via stdin. If it cannot, then a temporary
    file will be created and passed as an argument instead. By default,
    ImageMagick ("display") is the default program to use and it is read
    using stdin.

    >>>setDisplayProgram "gimp" False
    
    >>>setDisplayProgram "xv" False

    >>>setDisplayProgram "display" True
 -}
setDisplayProgram :: String -> Bool -> IO ()
setDisplayProgram program stdin = writeIORef displayProgram program >> writeIORef useStdin stdin


{-| Makes a call to the current display program to be displayed. If the
    program cannot read from standard in, a file named ".tmp-img" is created
    and used as an argument to the program.

    >>>frog <- readImage "images/frog.pgm"
    >>>display frog

 -}
display :: (DisplayFormat df) => df -> IO (Handle, Handle, Handle, ProcessHandle)
display img = do
  usestdin <- readIORef useStdin
  display <- readIORef displayProgram
  if usestdin then runCommandWithStdIn display . format $ img
              else do
    writeImage ".tmp-img" img
    runInteractiveCommand (display ++ " .tmp-img")

displayProgram :: IORef String
displayProgram = unsafePerformIO $ do
  dp <- newIORef "display"
  return dp

useStdin :: IORef Bool
useStdin = unsafePerformIO $ do
  usestdin <- newIORef True
  return usestdin
  
-- Run a command via the shell with the input given as stdin
runCommandWithStdIn :: String -> String -> IO (Handle, Handle, Handle, ProcessHandle)
runCommandWithStdIn cmd stdin =
  do
    ioval <- runInteractiveCommand cmd
    let stdInput = (\ (x, _, _, _) -> x) ioval
    hPutStr stdInput stdin
    hFlush stdInput
    hClose stdInput
    return ioval

{-| Takes a list, pair, or triple of images and passes them to 
    gnuplot to be displayed as histograms.

    >>>frog <- readImage "images/frog.pgm"
    >>>plotHistograms $ [frog]

    <https://raw.github.com/jcollard/unm-hip/master/examples/frog.jpg>

    <https://raw.github.com/jcollard/unm-hip/master/examples/frogplot.jpg>

    >>>cactii <- readColorImage "images/cactii.ppm"
    >>>plotHistograms . colorImageToRGB $ cactii

    <https://raw.github.com/jcollard/unm-hip/master/examples/cactii.jpg>

    <https://raw.github.com/jcollard/unm-hip/master/examples/cactiiplot.jpg>
 -}
plotHistograms images = runCommandWithStdIn "gnuplot -persist"  $ input
  where input = intercalate "\n" [plotCommand datas max, histogramList, "exit"]
        datas = [ "data" ++ (show x) | x <- [0..n]]
        n = length . toList $ images
        histogramList = intercalate "\ne" . map histogramString . toList $ images
        max = floor . maximum . map maxIntensity . toList $ images

-- Creates a plot command for gnuplot containing a title for each of the titles
-- and sets the width of the plot to be from 0 to max
plotCommand :: [String] -> Int -> String
plotCommand titles max = "plot [0:" ++ (show max) ++ "]" ++ (intercalate "," $ vals)
  where vals = [ " '-' title '" ++ title ++ "' with lines" | title <- titles]

-- Takes an image and creates a gnuplot command of the points for the
-- histogram.
histogramString img = intercalate "\n" $ map show (V.toList arr)
  where arr = areas img