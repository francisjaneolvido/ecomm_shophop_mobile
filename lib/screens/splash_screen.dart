import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'landing_screen.dart';



class SplashScreen extends StatefulWidget {

  const SplashScreen({
    super.key,
  });


  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();

}





class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {


  late AnimationController _controller;



  // Logo animations

  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _logoSlide;
  late Animation<double> _logoRotate;

  late Animation<double> _bounce;

  late Animation<double> _shadowScale;





  // Effects

  late Animation<double> _particleAnimation;

  late Animation<double> _glowAnimation;





  // Text

  late Animation<double> _textOpacity;

  late Animation<double> _textSlide;

  late Animation<double> _textScale;





  // ignore: unused_field
  final Random _random = Random();





  @override
  void initState() {

    super.initState();



    _controller = AnimationController(

      vsync: this,

      duration:
          const Duration(
            milliseconds: 3000,
          ),

    );





    // ================================
    // LOGO FADE
    // ================================


    _logoOpacity =
        CurvedAnimation(

          parent: _controller,

          curve:
              const Interval(

                0,

                .2,

                curve:
                    Curves.easeOut,

              ),

        );







    // ================================
    // LOGO SCALE POP
    // ================================


    _logoScale =
        Tween<double>(

          begin:
              .55,

          end:
              1,

        ).animate(

          CurvedAnimation(

            parent:
                _controller,


            curve:
                const Interval(

                  0,

                  .45,

                  curve:
                      Curves.elasticOut,

                ),

          ),

        );







    // ================================
    // SLIDE FROM RIGHT
    // ================================


    _logoSlide =
        Tween<double>(

          begin:
              180,

          end:
              0,

        ).animate(

          CurvedAnimation(

            parent:
                _controller,


            curve:
                const Interval(

                  0,

                  .45,

                  curve:
                      Curves.easeOutCubic,

                ),

          ),

        );








    // ================================
    // ROTATION ENTRY
    // ================================


    _logoRotate =
        Tween<double>(

          begin:
              .25,

          end:
              0,

        ).animate(

          CurvedAnimation(

            parent:
                _controller,


            curve:
                const Interval(

                  0,

                  .45,

                  curve:
                      Curves.easeOut,

                ),

          ),

        );









    // ================================
    // EXTRA BOUNCE
    // ================================


    _bounce =
        TweenSequence<double>([



          TweenSequenceItem<double>(

            tween:

                Tween<double>(

                  begin:
                      0,

                  end:
                      -25,

                ).chain(

                  CurveTween(

                    curve:
                        Curves.easeOut,

                  ),

                ),


            weight:
                35,

          ),





          TweenSequenceItem<double>(

            tween:

                Tween<double>(

                  begin:
                      -25,

                  end:
                      8,

                ).chain(

                  CurveTween(

                    curve:
                        Curves.bounceOut,

                  ),

                ),


            weight:
                35,

          ),





          TweenSequenceItem<double>(

            tween:

                Tween<double>(

                  begin:
                      8,

                  end:
                      0,

                ).chain(

                  CurveTween(

                    curve:
                        Curves.easeOut,

                  ),

                ),


            weight:
                30,

          ),



        ]).animate(

          CurvedAnimation(

            parent:
                _controller,


            curve:
                const Interval(

                  .25,

                  .75,

                ),

          ),

        );








    // ================================
    // SHADOW IMPACT
    // ================================


    _shadowScale =
        Tween<double>(

          begin:
              .25,

          end:
              1,

        ).animate(

          CurvedAnimation(

            parent:
                _controller,


            curve:
                const Interval(

                  .3,

                  .75,

                  curve:
                      Curves.easeOut,

                ),

          ),

        );









    // ================================
    // PARTICLES
    // ================================


    _particleAnimation =
        CurvedAnimation(

          parent:
              _controller,


          curve:
              const Interval(

                .45,

                .8,

                curve:
                    Curves.elasticOut,

              ),

        );






    // ================================
    // LOGO GLOW
    // ================================


    _glowAnimation =
        Tween<double>(

          begin:
              .2,

          end:
              1,

        ).animate(

          CurvedAnimation(

            parent:
                _controller,


            curve:
                const Interval(

                  .35,

                  .8,

                  curve:
                      Curves.easeInOut,

                ),

          ),

        );





    // ================================
    // TEXT
    // ================================


    _textOpacity =
        CurvedAnimation(

          parent:
              _controller,


          curve:
              const Interval(

                .7,

                1,

                curve:
                    Curves.easeOut,

              ),

        );




    _textSlide =
        Tween<double>(

          begin:
              35,

          end:
              0,

        ).animate(

          CurvedAnimation(

            parent:
                _controller,


            curve:
                const Interval(

                  .7,

                  1,

                  curve:
                      Curves.easeOut,

                ),

          ),

        );





    _textScale =
        Tween<double>(

          begin:
              .7,

          end:
              1,

        ).animate(

          CurvedAnimation(

            parent:
                _controller,


            curve:
                const Interval(

                  .7,

                  1,

                  curve:
                      Curves.elasticOut,

                ),

          ),

        );






    _controller.forward();





    Future.delayed(

      const Duration(

        milliseconds:
            3500,

      ),

      _openLanding,

    );

  }






  void _openLanding(){


    if(!mounted) return;



    Navigator.pushReplacement(

      context,


      PageRouteBuilder(

        transitionDuration:
            const Duration(
              milliseconds:
                  700,
            ),



        pageBuilder:
            (_, animation, __){


              return FadeTransition(

                opacity:
                    animation,


                child:
                    const LandingScreen(),

              );


            },


      ),


    );


  }






  @override
  void dispose(){

    _controller.dispose();

    super.dispose();

  }

    // ================================
  // PARTICLE WIDGET
  // ================================

  Widget _particle(
      double x,
      double y,
      double size,
  ) {

    return AnimatedBuilder(

      animation:
          _particleAnimation,


      builder:
          (_, child) {


        return Positioned(

          left:
              x,

          top:
              y,


          child:

          Transform.scale(

            scale:
                _particleAnimation.value,


            child:
                child,


          ),


        );


      },


      child:

      Container(

        width:
            size,

        height:
            size,


        decoration:

        BoxDecoration(


          shape:
              BoxShape.circle,


          color:
              AppColors.teal,


          boxShadow:[

            BoxShadow(

              color:
                  AppColors.teal
                      .withValues(
                        alpha:
                            .7,
                      ),


              blurRadius:
                  12,

            ),

          ],


        ),

      ),


    );

  }







  Widget _particles(){


    return SizedBox(

      width:
          180,

      height:
          120,


      child:

      Stack(

        children:[


          _particle(
            20,
            45,
            6,
          ),


          _particle(
            150,
            40,
            5,
          ),


          _particle(
            80,
            5,
            4,
          ),


          _particle(
            90,
            95,
            5,
          ),


          _particle(
            45,
            80,
            3,
          ),


          _particle(
            130,
            75,
            4,
          ),


        ],

      ),

    );


  }









  @override
  Widget build(BuildContext context){


    return Scaffold(


      backgroundColor:
          AppColors.navy,



      body:


      Center(


        child:

        Column(

          mainAxisSize:
              MainAxisSize.min,


          children:[






            // ================================
            // LOGO AREA
            // ================================


            SizedBox(

              height:
                  220,


              child:

              Stack(

                alignment:
                    Alignment.center,


                children:[




                  // particles

                  _particles(),






                  // logo glow

                  AnimatedBuilder(

                    animation:
                        _glowAnimation,


                    builder:
                        (_, child){


                      return Container(


                        decoration:

                        BoxDecoration(


                          boxShadow:[


                            BoxShadow(

                              color:

                              AppColors.teal
                                  .withValues(

                                    alpha:

                                    .25 *
                                    _glowAnimation.value,

                                  ),


                              blurRadius:

                                  55,

                            ),


                          ],


                        ),



                        child:
                            child,


                      );


                    },



                    child:

                    AnimatedBuilder(

                      animation:
                          _controller,


                      builder:
                          (_, child){



                        return Transform.translate(


                          offset:

                          Offset(

                            _logoSlide.value,

                            _bounce.value,

                          ),



                          child:

                          Transform.rotate(


                            angle:

                            _logoRotate.value,



                            child:

                            Transform.scale(


                              scale:

                              _logoScale.value,



                              child:


                              Opacity(


                                opacity:

                                _logoOpacity.value,


                                child:
                                    child,


                              ),



                            ),


                          ),


                        );


                      },



                      child:

                      Image.asset(

                        'assets/images/logo.png',


                        width:
                            150,


                      ),


                    ),


                  ),



                ],


              ),


            ),








            // ================================
            // SHADOW
            // ================================


            AnimatedBuilder(

              animation:
                  _shadowScale,


              builder:
                  (_, __){


                return Transform.scale(

                  scaleX:
                      _shadowScale.value,


                  child:


                  Container(

                    width:
                        75,

                    height:
                        9,


                    decoration:

                    BoxDecoration(


                      color:

                          Colors.black
                              .withValues(

                                alpha:
                                    .28,

                              ),


                      borderRadius:

                          BorderRadius.circular(
                            50,
                          ),


                    ),


                  ),


                );


              },

            ),







            const SizedBox(

              height:
                  35,

            ),








            // ================================
            // WORDMARK
            // ================================


            AnimatedBuilder(

              animation:
                  _textOpacity,


              builder:
                  (_, child){


                return Opacity(


                  opacity:

                  _textOpacity.value,



                  child:

                  Transform.translate(


                    offset:

                    Offset(

                      0,

                      _textSlide.value,

                    ),



                    child:


                    Transform.scale(

                      scale:

                      _textScale.value,


                      child:
                          child,


                    ),


                  ),


                );


              },




              child:

              Column(


                children:[





                  RichText(

                    text:


                    TextSpan(

                      children:[



                        TextSpan(

                          text:
                              "Shop",


                          style:

                          TextStyle(


                            color:
                                Colors.white,


                            fontSize:
                                32,


                            fontWeight:
                                FontWeight.w800,


                            letterSpacing:
                                .5,


                          ),


                        ),





                        TextSpan(

                          text:
                              "Hop",


                          style:

                          TextStyle(


                            color:
                                AppColors.teal,


                            fontSize:
                                32,


                            fontWeight:
                                FontWeight.w800,


                          ),


                        ),



                      ],


                    ),

                  ),








                  const SizedBox(

                    height:
                        8,

                  ),






                  Text(

                    "HOP IN. SHOP MORE.",



                    style:

                    TextStyle(


                      color:

                          AppColors.teal,


                      fontSize:
                          11,


                      fontWeight:
                          FontWeight.w700,


                      letterSpacing:
                          2.8,


                    ),


                  ),






                  const SizedBox(

                    height:
                        35,

                  ),







                  SizedBox(

                    width:
                        55,


                    child:

                    ClipRRect(

                      borderRadius:

                          BorderRadius.circular(
                            20,
                          ),


                      child:

                      LinearProgressIndicator(


                        minHeight:
                            4,



                        backgroundColor:

                            Colors.white
                                .withValues(

                                  alpha:
                                      .15,

                                ),



                        valueColor:

                        AlwaysStoppedAnimation(

                          AppColors.teal,

                        ),


                      ),


                    ),


                  ),





                ],

              ),


            ),





          ],


        ),


      ),


    );


  }

}