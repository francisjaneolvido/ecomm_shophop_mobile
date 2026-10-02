import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'authentication/login_screen.dart';



class LandingScreen extends StatefulWidget {

  const LandingScreen({
    super.key,
  });


  @override
  State<LandingScreen> createState() =>
      _LandingScreenState();

}



class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {


  late AnimationController _controller;


  late Animation<double> _fade;

  late Animation<double> _slide;

  late Animation<double> _scale;




  @override
  void initState(){

    super.initState();


    _controller =
        AnimationController(

          vsync: this,

          duration:
              const Duration(
                milliseconds: 1200,
              ),

        );



    _fade =
        CurvedAnimation(

          parent:
              _controller,


          curve:
              Curves.easeOut,

        );




    _slide =
        Tween<double>(

          begin:
              40,

          end:
              0,

        ).animate(

          CurvedAnimation(

            parent:
                _controller,


            curve:
                Curves.easeOutCubic,

          ),

        );




    _scale =
        Tween<double>(

          begin:
              .8,

          end:
              1,

        ).animate(

          CurvedAnimation(

            parent:
                _controller,


            curve:
                Curves.elasticOut,

          ),

        );



    _controller.forward();


  }





  @override
  void dispose(){

    _controller.dispose();

    super.dispose();

  }







  @override
  Widget build(BuildContext context){


    return Scaffold(


      body:


      Container(


        decoration:


        BoxDecoration(


          gradient:


          LinearGradient(


            begin:
                Alignment.topCenter,


            end:
                Alignment.bottomCenter,



            colors:[


              Colors.white,


              AppColors.tealLight
                  .withValues(
                    alpha:
                        .35,
                  ),


            ],


          ),


        ),





        child:


        SafeArea(


          child:


          Padding(


            padding:

            const EdgeInsets.symmetric(

              horizontal:
                  28,

            ),



            child:


            Column(


              children:[





                const Spacer(),








                FadeTransition(

                  opacity:
                      _fade,


                  child:


                  ScaleTransition(

                    scale:
                        _scale,


                    child:

                    Image.asset(

                      'assets/images/logo.png',

                      width:
                          120,

                    ),


                  ),


                ),








                const SizedBox(

                  height:
                      35,

                ),








                FadeTransition(

                  opacity:
                      _fade,


                  child:

                  Transform.translate(


                    offset:

                    Offset(

                      0,

                      _slide.value,

                    ),



                    child:


                    Column(

                      children:[




                        Text(

                          "Everything You Love,\nJust a Hop Away.",



                          textAlign:
                              TextAlign.center,


                          style:


                          TextStyle(


                            color:
                                AppColors.navy,


                            fontSize:
                                28,


                            height:
                                1.25,


                            fontWeight:
                                FontWeight.w800,


                            letterSpacing:
                                -.3,


                          ),


                        ),








                        const SizedBox(

                          height:
                              16,

                        ),








                        Text(


                          "Discover everyday essentials,\ntrending finds, and products you'll love\nall in one place.",



                          textAlign:
                              TextAlign.center,


                          style:


                          TextStyle(


                            color:

                            AppColors.navy
                                .withValues(
                                  alpha:
                                      .6,
                                ),


                            fontSize:
                                14,


                            height:
                                1.6,


                          ),


                        ),




                      ],


                    ),


                  ),


                ),









                const SizedBox(

                  height:
                      45,

                ),









                // FEATURE CARDS


                Row(


                  mainAxisAlignment:
                      MainAxisAlignment.center,


                  children:[


                    _miniCard(

                      Icons.shopping_bag_outlined,

                      "Shop",

                    ),


                    const SizedBox(
                      width:
                          12,
                    ),


                    _miniCard(

                      Icons.local_shipping_outlined,

                      "Fast",

                    ),


                    const SizedBox(
                      width:
                          12,
                    ),


                    _miniCard(

                      Icons.favorite_border,

                      "Loved",

                    ),



                  ],


                ),







                const Spacer(),







                SizedBox(


                  width:
                      double.infinity,


                  height:
                      56,



                  child:


                  ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  },


                    style:


                    ElevatedButton.styleFrom(


                      backgroundColor:
                          AppColors.teal,


                      foregroundColor:
                          AppColors.navy,


                      elevation:
                          0,


                      shape:


                      RoundedRectangleBorder(


                        borderRadius:

                        BorderRadius.circular(
                          18,
                        ),


                      ),


                    ),



                    child:


                    const Text(


                      "Get Started",



                      style:


                      TextStyle(


                        fontSize:
                            16,


                        fontWeight:
                            FontWeight.w700,


                      ),


                    ),


                  ),


                ),








                const SizedBox(

                  height:
                      12,

                ),







                TextButton(


                  onPressed:(){},


                  child:


                  RichText(


                    text:


                    TextSpan(


                      text:
                          "Already have an account? ",


                      style:


                      TextStyle(

                        color:

                        AppColors.navy
                            .withValues(
                              alpha:
                                  .6,
                            ),

                        fontSize:
                            13,

                      ),




                      children:[



                        TextSpan(


                          text:
                              "Sign In",


                          style:


                          TextStyle(


                            color:
                                AppColors.tealDark,


                            fontWeight:
                                FontWeight.w700,


                          ),


                        ),



                      ],


                    ),


                  ),


                ),







                const SizedBox(

                  height:
                      20,

                ),





              ],


            ),


          ),


        ),


      ),


    );


  }









  Widget _miniCard(
      IconData icon,
      String text,
  ){


    return Container(


      width:
          75,


      height:
          70,



      decoration:


      BoxDecoration(


        color:
            Colors.white,


        borderRadius:
            BorderRadius.circular(
              18,
            ),



        boxShadow:[


          BoxShadow(


            color:

            Colors.black
                .withValues(
                  alpha:
                      .05,
                ),


            blurRadius:
                15,


            offset:
                const Offset(
                  0,
                  5,
                ),


          ),


        ],


      ),




      child:


      Column(

        mainAxisAlignment:
            MainAxisAlignment.center,


        children:[



          Icon(

            icon,


            color:
                AppColors.teal,


            size:
                25,

          ),




          const SizedBox(

            height:
                6,

          ),




          Text(

            text,


            style:

            TextStyle(

              color:
                  AppColors.navy,

              fontSize:
                  11,

              fontWeight:
                  FontWeight.w600,

            ),

          ),



        ],


      ),


    );


  }



}