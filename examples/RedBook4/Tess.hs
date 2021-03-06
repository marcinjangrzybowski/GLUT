{-
   Tess.hs (adapted from tess.c which is (c) Silicon Graphics, Inc)
   Copyright (c) Sven Panne 2002-2018 <svenpanne@gmail.com>
   This file is part of HOpenGL and distributed under a BSD-style license
   See the file libraries/GLUT/LICENSE

   This program demonstrates polygon tessellation. Two tesselated objects are
   drawn. The first is a rectangle with a triangular hole. The second is a
   smooth shaded, self-intersecting star.

   Note the exterior rectangle is drawn with its vertices in counter-clockwise
   order, but its interior clockwise. Note the combineCallback is needed for the
   self-intersecting star. Also note that removing the TessProperty for the
   star will make the interior unshaded (TessWindingOdd).
-}

import System.Exit ( exitWith, ExitCode(ExitSuccess) )
import Graphics.UI.GLUT

display :: [DisplayList] -> DisplayCallback
display displayLists = do
   clear [ ColorBuffer ]
   -- resolve overloading, not needed in "real" programs
   let color3f = color :: Color3 GLfloat -> IO ()
   color3f (Color3 1 1 1)
   mapM_ callList displayLists
   flush

-- 'Float' is a dummy, any marshalable type would do
type DontCare = Float

rectangle :: ComplexContour DontCare
rectangle = ComplexContour [
   AnnotatedVertex (Vertex3  50  50 0) 0,
   AnnotatedVertex (Vertex3 200  50 0) 0,
   AnnotatedVertex (Vertex3 200 200 0) 0,
   AnnotatedVertex (Vertex3  50 200 0) 0 ]

tri :: ComplexContour DontCare
tri = ComplexContour [
   AnnotatedVertex (Vertex3  75  75 0) 0,
   AnnotatedVertex (Vertex3 125 175 0) 0,
   AnnotatedVertex (Vertex3 175  75 0) 0 ]

rectAndTri :: ComplexPolygon DontCare
rectAndTri = ComplexPolygon [ rectangle, tri ]

noOpCombiner :: Combiner DontCare
noOpCombiner _newVertex _weightedProperties = 0

star :: ComplexPolygon (Color3 GLfloat)
star = ComplexPolygon [
   ComplexContour [
      AnnotatedVertex (Vertex3 250  50 0) (Color3 1 0 1),
      AnnotatedVertex (Vertex3 325 200 0) (Color3 1 1 0),
      AnnotatedVertex (Vertex3 400  50 0) (Color3 0 1 1),
      AnnotatedVertex (Vertex3 250 150 0) (Color3 1 0 0),
      AnnotatedVertex (Vertex3 400 150 0) (Color3 0 1 0) ] ]

combineColors :: Combiner (Color3 GLfloat)
combineColors
   _newVertex
   (WeightedProperties
      (w0, Color3 r0 g0 b0)
      (w1, Color3 r1 g1 b1)
      (w2, Color3 r2 g2 b2)
      (w3, Color3 r3 g3 b3)) =
         Color3 (w0*r0 + w1*r1 + w2*r2 + w3*r3)
                (w0*g0 + w1*g1 + w2*g2 + w3*g3)
                (w0*b0 + w1*b1 + w2*b2 + w3*b3)

myInit :: IO [DisplayList]
myInit = do
   clearColor $= Color4 0 0 0 0

   rectAndTriList <- defineNewList Compile $
      drawSimplePolygon (\_ -> return ()) =<<
         tessellate TessWindingOdd 0 (Normal3 0 0 0) noOpCombiner rectAndTri

   starList <- defineNewList Compile $
      drawSimplePolygon color =<<
         tessellate TessWindingPositive 0 (Normal3 0 0 0) combineColors star

   return [ rectAndTriList, starList ]

drawSimplePolygon :: (v -> IO ()) -> SimplePolygon v -> IO ()
drawSimplePolygon colorHandler (SimplePolygon primitives) =
   flip mapM_ primitives $ \(Primitive primitiveMode vertices) ->
      renderPrimitive primitiveMode $
         flip mapM_ vertices $ \(AnnotatedVertex plainVertex col) -> do
            colorHandler col
            vertex plainVertex

reshape :: ReshapeCallback
reshape size@(Size w h) = do
   viewport $= (Position 0 0, size)
   matrixMode $= Projection
   loadIdentity
   ortho2D 0 (fromIntegral w) 0 (fromIntegral h)
   matrixMode $= Modelview 0
   loadIdentity

keyboard :: KeyboardMouseCallback
keyboard (Char '\27') Down _ _ = exitWith ExitSuccess
keyboard _            _    _ _ = return ()

main :: IO ()
main = do
   (progName, _args) <- getArgsAndInitialize
   initialDisplayMode $= [ SingleBuffered, RGBMode ]
   initialWindowSize $= Size 500 500
   _ <- createWindow progName
   displayLists <- myInit
   displayCallback $= display displayLists
   reshapeCallback $= Just reshape
   keyboardMouseCallback $= Just keyboard
   mainLoop
