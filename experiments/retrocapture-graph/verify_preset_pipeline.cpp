// Runs the real RetroCapture ShaderEngine using a hidden GLFW OpenGL context.
// Source remains unchanged. Reports RGBA GPU readback of a synthetic
// nonuniform image through an actual .glslp preset, not a simulated graph.
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include "shader/ShaderEngine.h"
#include "renderer/glad_loader.h"
#include "utils/Logger.h"
#include <vector>
#include <cstdint>
#include <cstdio>
#include <string>
#include <cstdlib>
#include <cstring>

struct Receipt { unsigned long long rgba=0; size_t varied=0, nonzero=0; unsigned char center[4]{}; };
static Receipt render(ShaderEngine &engine, GLuint src, GLuint fbo,
                      int w,int h,int kind,int tick) {
    std::vector<uint8_t> pixels(size_t(w)*h*4);
    for(int y=0;y<h;y++)for(int x=0;x<w;x++) {
        const size_t i=(size_t(y)*w+x)*4;
        const int grid=((x/7+y/9)&1);
        if(kind==2) {
            pixels[i]=tick==0?210:25;
            pixels[i+1]=tick==0?35:185;
            pixels[i+2]=tick==0?30:220;
        } else {
            pixels[i]=uint8_t((x*210/w)+(grid?33:0));
            pixels[i+1]=uint8_t((y*205/h)+(grid?31:0));
            pixels[i+2]=uint8_t((x*4+y*2)%256);
        }
        pixels[i+3]=255;
    }
    glBindTexture(GL_TEXTURE_2D,src);
    glTexSubImage2D(GL_TEXTURE_2D,0,0,0,w,h,GL_RGBA,GL_UNSIGNED_BYTE,pixels.data());
    engine.setViewport(w,h);
    GLuint output=engine.applyShader(src,w,h);
    if(!output) {std::fprintf(stderr,"ZERO_OUTPUT frame=%d\n",tick);std::exit(7);}
    glBindFramebuffer(GL_FRAMEBUFFER,fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,output,0);
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER)!=GL_FRAMEBUFFER_COMPLETE) {
      std::fprintf(stderr,"INCOMPLETE READBACK\n");std::exit(8);
    }
    std::vector<uint8_t> frame(size_t(w)*h*4,0);
    glReadPixels(0,0,w,h,GL_RGBA,GL_UNSIGNED_BYTE,frame.data());
    Receipt r;
    for(size_t i=0;i<frame.size();i+=4) {
       r.rgba+=frame[i]+frame[i+1]+frame[i+2]+frame[i+3];
       if(frame[i]!=frame[4] || frame[i+1]!=frame[5] || frame[i+2]!=frame[6])r.varied++;
       if(frame[i]+frame[i+1]+frame[i+2]>10)r.nonzero++;
    }
    std::memcpy(r.center,frame.data()+((h/2)*w+w/2)*4,4);
    std::printf("FRAME=%d INPUT_VARIANT=%d OUT=%ux%u CHECKSUM=%llu VARIED=%zu NONBLACK=%zu CENTER=%u,%u,%u,%u\n",
        tick,kind,engine.getOutputWidth(),engine.getOutputHeight(),r.rgba,r.varied,r.nonzero,
        r.center[0],r.center[1],r.center[2],r.center[3]);
    return r;
}
int main(int argc,char**argv) {
  if(argc!=3){std::fprintf(stderr,"Usage: %s PRESET.glslp MODE[spatial|history|feedback]\n",argv[0]);return 2;}
  const bool history=std::string(argv[2])=="history";
  const bool feedback=std::string(argv[2])=="feedback";
  const int w=160,h=120;
  if(!glfwInit()){std::fprintf(stderr,"GLFW_INIT_FAIL\n");return 2;}
  glfwWindowHint(GLFW_VISIBLE,GLFW_FALSE);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR,3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR,3);
  glfwWindowHint(GLFW_OPENGL_PROFILE,GLFW_OPENGL_CORE_PROFILE);
  GLFWwindow *win=glfwCreateWindow(w,h,"RetroCapture GLSLP verification",nullptr,nullptr);
  if(!win){std::fprintf(stderr,"GLFW_WINDOW_FAIL\n");glfwTerminate();return 3;}
  glfwMakeContextCurrent(win);
  ShaderEngine engine;
  if(!engine.init()){std::fprintf(stderr,"ENGINE_INIT_FAIL\n");return 4;}
  if(!engine.loadPreset(argv[1])){std::fprintf(stderr,"PRESET_LOAD_FAIL %s\n",argv[1]);return 5;}
  std::printf("PRESET_LOADED=1 PASSES=%zu\n",engine.getPreset().getPasses().size());
  GLuint source=0,readback=0;
  glGenTextures(1,&source);
  glBindTexture(GL_TEXTURE_2D,source);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,w,h,0,GL_RGBA,GL_UNSIGNED_BYTE,nullptr);
  glGenFramebuffers(1,&readback);
  auto first=render(engine,source,readback,w,h,history?2:0,0);
  auto second=render(engine,source,readback,w,h,history?2:0,1);
  auto third=render(engine,source,readback,w,h,history?2:0,2);
  int result=0;
  if(engine.getPreset().getPasses().size()<1 || first.nonzero==0 || second.nonzero==0)result=10;
  if(history) {
    // Input changed at frame 1; response-time output should differ
    // on the next frame even though input is then held constant.
    if(second.rgba==third.rgba && std::memcmp(second.center,third.center,4)==0)result=11;
  } else if(feedback) {
    if(first.rgba==second.rgba || second.rgba==third.rgba)result=13;
  } else {
    // A real multi-pass result should not be byte-for-byte pass-through.
    unsigned long long rawChecksum=0;
    for(int y=0;y<h;++y)for(int x=0;x<w;++x) {
      int checker=((x/7+y/9)&1);
      rawChecksum+=(x*210/w)+(checker?33:0)
                   +(y*205/h)+(checker?31:0)
                   +(x*4+y*2)%256+255;
    }
    if(first.varied<size_t(w*h/5) || first.rgba==rawChecksum
       || engine.getPreset().getPasses().size()<2)result=12;
  }
  std::printf("GLSLP_GRAPH_RENDER_PASS=%d MODE=%s\n",result==0,history?"history":(feedback?"feedback":"spatial"));
  engine.shutdown();
  glDeleteFramebuffers(1,&readback);glDeleteTextures(1,&source);
  glfwDestroyWindow(win);glfwTerminate();
  return result;
}
