export {init} from 'vgpu';
import {createImageFeedbackGraph} from './image-feedback.mjs';
export const createExternalVideoGraph=gpu=>createImageFeedbackGraph(gpu,{videoInput:'external'});
