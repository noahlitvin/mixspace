import processing.opengl.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.spi.*;
import peasy.*;
import controlP5.*;
import javax.swing.*; 

Minim minim;
float[][] spectra;
ArrayList<Layer> layers = new ArrayList<Layer>();

PeasyCam cam;

ControlP5 controlP5;
MultiList layerGUI;

void setup()
{
  size(800, 600, OPENGL);
  frameRate(30);

  minim = new Minim(this);
  minim.debugOn();
  
  controlP5 = new ControlP5(this);
  controlP5.addButton("addLayer",0,25,20,200,40).setLabel("(+) Add New Layer");
  layerGUI = controlP5.addMultiList("Layers",25,70,200,40);
  
  controlP5.addButton("play",0,width-25-200,20,200,40).setLabel("Play");
  
  cam = new PeasyCam(this, 200, 200, -200, 200);
  cam.rotateX(160);
  controlP5.setAutoDraw(false);
}

void draw()
{
  float dt = 1.0 / frameRate;
  
  background(0);

  for (int i = 0; i < layers.size(); i ++ ) {
    layers.get(i).display();
  }
  
  cam.beginHUD();
  controlP5.draw();
  cam.endHUD();
  
}

void stop()
{
  minim.stop();
  super.stop();
}

void controlEvent(ControlEvent theEvent) {
  if(theEvent.controller().name() == "play"){
    playLayers();
  } else if(theEvent.controller().name() == "addLayer"){
    addNewLayer();
  }
}

public void addNewLayer() {
  noLoop();
  try { 
    UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName()); 
  } catch (Exception e) { 
    e.printStackTrace();   
  } 
   
  // create a file chooser 
  final JFileChooser fc = new JFileChooser(); 
   
  // in response to a button click: 
  int returnVal = fc.showOpenDialog(this); 
 
  if (returnVal == JFileChooser.APPROVE_OPTION) { 
    File file = fc.getSelectedFile();
    if (file.getName().endsWith("wav") || file.getName().endsWith("mp3")){
      layers.add(new Layer(file.getName(),file.getPath(),color(random(255),random(255),random(255))));
    }
  }
  loop();
}

public void playLayers() {
  for(int i = 0; i < layers.size(); i++){
    layers.get(i).playSample();
  }
}

class Layer {
  AudioSample sample;
  color fillcolor;
  float[][] spectra;
  String layername;
  
  Layer(String n, String filepath, color c)  { 
    layername = n;   
    fillcolor = c;
    sample = minim.loadSample(filepath, 2048);
    spectra = buildSpectra(sample);

    //Add to GUI list
    MultiListButton li = layerGUI.add("layer" + layers.size(),layers.size());
    li.setLabel(layername);
    li.setColorBackground(fillcolor);
  }

  public void playSample(){
    sample.trigger();
  }

  public float[][] getSpectra(){
    return spectra;
  }
    
  public void display(){
    fill(fillcolor);
    
    for(int s = 0; s < spectra.length-1; s++){
      
      beginShape(TRIANGLE_STRIP);
      for(int i = 0; i < spectra[s].length; i++ ) {
        
        float booster1 = 0;
        float booster2 = 0;
        if(layers.indexOf(this) > 0){ //TODO fix below to not require try/catch
          try{
            booster1 = layers.get(layers.indexOf(this)-1).getSpectra()[s][i];
          }
          catch( ArrayIndexOutOfBoundsException e ) 
          {}
          try{
            booster2 = layers.get(layers.indexOf(this)-1).getSpectra()[s+1][i];
          }
          catch( ArrayIndexOutOfBoundsException e ) 
          {}
        }
        
        vertex(-256 + i, spectra[s][i] + booster1, s * 50);
        vertex(-256 + i, spectra[s+1][i] + booster2, (s+1) * 50);
      }
      endShape();
      
    }
    
  }  
}

public float[][] buildSpectra(AudioSample jingle)
{
  // get the left channel of the audio as a float array
  // getChannel is defined in the interface BuffereAudio, 
  // which also defines two constants to use as an argument
  // BufferedAudio.LEFT and BufferedAudio.RIGHT
  float[] leftChannel = jingle.getChannel(BufferedAudio.LEFT);
  // then we create an array we'll copy sample data into for the FFT object
  // this should be as large as you want your FFT to be. generally speaking, 2048 is probably fine.
  int fftSize = 2048;
  float[] fftSamples = new float[fftSize];
  FFT fft = new FFT( fftSize, jingle.sampleRate() );
  // now we'll analyze the samples in chunks
  int totalChunks = (leftChannel.length / fftSize) + 1;
  // allocate a 2-dimentional array that will hold all of the spectrum data for all of the chunks.
  // the second dimension if fftSize/2 because the spectrum size is always half the number of samples analyzed.
  spectra = new float[totalChunks][fftSize/2];
  for(int chunkIdx = 0; chunkIdx < totalChunks; ++chunkIdx)
  {
    int chunkStartIndex = chunkIdx * fftSize;
    // the chunk size will always be fftSize, except for the 
    // last chunk, which will be however many samples are left in source
    int chunkSize = min( leftChannel.length - chunkStartIndex, fftSize );
    // copy first chunk into our analysis array
    arraycopy( leftChannel, // source of the copy
               chunkStartIndex, // index to start in the source
               fftSamples, // destination of the copy
               0, // index to copy to
               chunkSize // how many samples to copy
              );
      
    // if the chunk was smaller than the fftSize, we need to pad the analysis buffer with zeroes        
    if ( chunkSize < fftSize )
    {
      // we use a system call for this
      Arrays.fill( fftSamples, chunkSize, fftSamples.length - 1, 0.0 );
    }
    
    // now analyze this buffer
    fft.forward( fftSamples );
    // and copy the resulting spectrum into our spectra array
    for(int i = 0; i < 512; ++i)
    {
      spectra[chunkIdx][i] = fft.getBand(i);
    }
  }
  jingle.close();
  return spectra;
}
