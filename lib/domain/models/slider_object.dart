class SliderObject {
  final String title;
  final String subtitle;
  final String imagePath;

  SliderObject(this.title, this.subtitle, this.imagePath);
}

class SliderViewObject {
  SliderObject sliderObject;
  int numOfSlides;
  int currentIndex;

  SliderViewObject(this.sliderObject, this.numOfSlides, this.currentIndex);
}
