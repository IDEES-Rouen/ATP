/***
* Name: MetaModel
* Author: mathieu
* Description: general model for the spreading of wares
* Tags: Tag1, Tag2, TagN
***/

model MetaModel

global schedules: shuffle(Consumer) + shuffle(Intermediary) + shuffle(Ware) + shuffle(Producer){
	int nb_init_Consumer <- 2 parameter: true;
	int nb_init_Intermediary <- 1 parameter: true;
	int nb_init_prod <- 2 parameter: true;
	geometry shape <- square(200/*0*/);
	float averageDistance <- 0.0;
	float distanceMax <- 0.0;
	float distanceMin <- 0.0;
	int prodRate <- 5 parameter:true;
	int prodRateFixed <- 50 parameter:true;
	int consumRate <- 5 parameter:true;
	int consumRateFixed <- 50 parameter:true;
	int capacityInter <- 30 parameter: true;
	int stock_max_prod <- 10 parameter: true;
	int stock_max_prod_fixe <- 100 parameter: true;
	
	init {
		do createConsum(nb_init_Consumer);
		do createProd(nb_init_prod);
		do createInter(nb_init_Intermediary);
	}
	
	user_command "create consum"{
		do createConsum(1);
	}
	
	user_command "destroy consum"{
		do destroyConsum;
	}
	
	user_command "create prod"{
		do createProd(1);
	}
	
	user_command "destroy prod"{
		do destroyProd;
	}
	
	user_command "create inter"{
		do createInter(1);
	}
	
	user_command "destroy inter"{
		do destroyInter;
	}
	
	action createConsum(int nb_consum){
		create Consumer number: nb_consum{
			create Intermediary number: 1{
				location <-myself.location;
				is_Consumer <- true;
				my_consum <- myself;
				is_Producer <- false;
				my_prod <- nil;
				capacity <- myself.need;
				stock <- myself.collect;
				money <- myself.money;
				
				ask myself{
					my_inter <- myself;
				}
			}
		}
	}
	
	action destroyConsum{
		ask one_of(Consumer){
			do die ;
		}
	}
	
	action createProd(int nb_prod){
		create Producer number: nb_prod{
			create Intermediary number: 1{
				location <-myself.location;
				is_Consumer <- false;
				my_consum <- nil;
				is_Producer <- true;
				my_prod <- myself;
				capacity <- myself.stockMax;
				stock <- myself.stock;
				
				ask myself{
					my_inter <- myself;
				}
			}
		}
	}
	
	action destroyProd{
		ask one_of(Producer){
			do die ;
		}
	}
	
	action createInter(int nb_inter){
		create Intermediary number: nb_inter{
			is_Producer <- false;
			my_prod <- nil;
			is_Consumer <- false;
			my_consum <- nil;
			capacity <- rnd(capacityInter);
		}
	}
	
	action destroyInter{
		ask one_of(Intermediary where ((not(each.is_Producer)) and (not(each.is_Consumer)))){
			do die ;
		}
	}
	
	reflex displayReflex {
		write "-------------------------";
		averageDistance <- 0.0;
		if(not empty(Ware)){
			distanceMax <- first(Ware).distance;
			distanceMin <- first(Ware).distance;
		}
		loop temp over: Ware{
			averageDistance<- averageDistance + temp.distance;
			if(temp.distance>distanceMax){
				distanceMax <- temp.distance;
			}
			if(temp.distance<distanceMin){
				distanceMin <- temp.distance;
			}
		}
		if(not empty(Ware)){
			averageDistance <- averageDistance/length(Ware);
		}
		if(not(empty(Ware))){
			loop tempProd over: Producer{
				bool exists <- false;
				loop tempPoly over: PolygonWare{
					if tempPoly.placeProd = tempProd {
						exists <- true;
					}
				}
				if(exists){
					PolygonWare polyChange <- PolygonWare first_with (each.placeProd=tempProd);
					list<Ware> tempWares <- Ware where (each.prodPlace = tempProd);
					if not empty(tempWares){
						list<Ware> wareKept;
						add first(tempWares) to: wareKept;
						list<Intermediary> placeVisited;
						add first(Intermediary where(first(wareKept).location = each.location)) to: placeVisited;
						loop tempWare over: tempWares{
							Intermediary placeWare <- first(Intermediary where(tempWare.location = each.location));
							if not (placeVisited contains placeWare){
								add tempWare to: wareKept;
								add placeWare to: placeVisited;
							}
						}
						polyChange.shape <- polygon(wareKept);
					}
				} else {
					create PolygonWare number: 1{
					placeProd <- tempProd;
					list<Ware> tempWares <- Ware where (each.prodPlace = tempProd);
					shape <- /*convex_hull(*/polygon(tempWares)/*)*/;
					}
				}
			}
		}
	}
	
}

species Consumer {
	//TODO //diversifier en fonction des types et ajouter la variable d'money.
	int money;
	int need <- consumRateFixed + rnd(consumRate) update:consumRateFixed + rnd(consumRate) ; //dans le cade de la craie, le need serait fixe et représenterait le need total de la construction 
	int collect <- 0 update: 0; //dans le cade de la craie, les matières récupérées ne seraient pas remise à zéro à chaque tour (cette remise à zéro symbolise la consommation)
	Intermediary my_inter; 
	
	bool is_built; //utilisé sur les bâtiments pour montrer que le batiment n'a plus need de pierre.
	
	reflex updateInterStart{
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
	//TODO add money in the computation
	reflex buying { //on achète à tous les intermédiaires qui ne sont pas des Consumers
//		do buy0;
		do buy1; //à remplacer en fonction de la méthode que l'on veut tester
//		do buy2;
	}
	
	action buy0{
		//choix aléatoire, quelques soit la distance, etc (utiliser le shuffle). Utilisé comm comparateur de base.
		loop tempInt over: shuffle(Intermediary where (not(each.is_Consumer))){
			if (collect<need){
				int collectTemp;
				collectTemp <- min(need,tempInt.stock);
				collect <- collect+collectTemp;
				if(tempInt.is_Producer){
					write "buy prod " + collectTemp;
				} else {
					write "buy inter " + collectTemp;
				}
				ask tempInt{
					stock <- stock - collectTemp;
				}
			}
		}
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
	action buy1 { //buy du maximum (en quantité) en fonction de la distance, sans pénalité rajoutée par les intermédiaires.
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer));
		temp <- temp sort_by(each distance_to self); //Le distance_to s'applique sur la topologie de l'agent appelant (chaque espèce possède une topology comme built-in attribute sur laquelle il évolue)
		loop tempInt over: temp{
			if (collect<need){
				int collectTemp;
				collectTemp <- min(need,tempInt.stock);
				collect <- collect+collectTemp;
				if(collectTemp>0){
					if(tempInt.is_Producer){
						write "buy prod " + collectTemp;
						create Ware number: 1{
							prodPlace <- tempInt.my_prod;
							origin <- tempInt;
							quantity <- collectTemp;
							target <- myself.location;
							distance <- myself distance_to tempInt.my_prod;
						}
					} else {
						write "buy inter " + collectTemp;
						list<Ware> tempWares <- Ware where(each.location = tempInt.location);
						bool endCollecting <- false;
						int recupWare<-0;
						loop tempLoop over: tempWares{
							if(not endCollecting){
								if (recupWare+tempLoop.quantity <= collectTemp) {
									recupWare <- recupWare + tempLoop.quantity;
									tempLoop.target <- self.location;
									tempLoop.distance <- tempLoop.distance + tempLoop distance_to self;
								} else {
									create Ware number: 1{
										quantity <- collectTemp-recupWare;
										target <- myself.location;
										distance <- tempLoop.distance + self distance_to myself;
										origin <- tempLoop.origin;
										prodPlace <- tempLoop.prodPlace;
									}
									tempLoop.quantity <- tempLoop.quantity - (collectTemp-recupWare);
									recupWare <- collectTemp;
								}
								if(recupWare >= collectTemp){
									endCollecting <- true;
								}
							}
						}
					}
					ask tempInt{
						stock <- stock - collectTemp;
					}
				}
			}
		}
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
	//TODO : préparer l'ajout d'un price ou le calcul d'une autre distance (ou les deux)
	action buy2{ // buy au plus loin
		list<Intermediary> temp <- Intermediary where (not(each.is_Consumer));
		temp <- temp sort_by(1/each distance_to self); //On peut mettre des expressions dans le sort_by.
		loop tempInt over: temp{
			if (collect<need){
				int collectTemp;
				collectTemp <- min(need,tempInt.stock);
				collect <- collect+collectTemp;
				if(tempInt.is_Producer){
					write "buy prod " + collectTemp;
				} else {
					write "buy inter " + collectTemp;
				}
				ask tempInt{
					stock <- stock - collectTemp;
				}
			}
		}
		my_inter.capacity <- need;
		my_inter.stock <- collect;
	}
	
	//un carré de couleur dont la taille peut varier en foction d'un paramètre (le need, l'money, etc ?)
	aspect base {
		draw square(10) color:#blue;
	}
}

//Dans un premier temps, chaque intermédiaire est spécialisé dans un seul type, sauf les Consumers qui auront les deux types (commun et supérieurs)
species Intermediary {
	int stock <- 0;
	int capacity <- rnd(capacityInter);
	int price <- 0;
	bool is_Producer;
	Producer my_prod;
	bool is_Consumer;
	Consumer my_consum;
	int money;
	
	//TODO : ajouter la capacité d'buy des intermédiaires, dans un cas de figure.
	
	aspect base {
		if(not(is_Producer) and not(is_Consumer)){
			if (stock>0){
				draw circle(stock) color:#green;
			} else {
				draw circle(1) color:#green;
			}	
		}
	}
}

species Producer{
	int production <- prodRateFixed + rnd(prodRate) update:prodRateFixed + rnd(prodRate) ;
	int stock <- 0 ;
	int stockMax <- stock_max_prod_fixe + rnd(stock_max_prod);
	Intermediary my_inter;
	
	reflex produit when: stock/*+production*/<stockMax{
		stock <- stock+production;
	}
	
	reflex updateInter{
		my_inter.stock<-stock;
	}
	
	reflex selling { //on vend à tous les intermédiaires qui ne sont pas des Producers
		if(my_inter.stock>0){
//			do sell0;
			do sell1;
//			do sell2;
		}
	}
	
	action sell0{
		//choix aléatoire, quelques soit la distance, etc (utiliser le shuffle). Utilisé comm comparateur de base.
		loop tempInt over: shuffle(Intermediary where not(each.is_Producer)){
				if(stock>0){
					ask tempInt{
						if(stock<capacity and myself.stock>0){
						int exchange <- min(capacity-stock,myself.stock);
						stock <- stock + exchange;
						myself.stock <- myself.stock-exchange;
							if(self.is_Consumer){
								write "sell conso " + self + " " + exchange;
							} else {
								write "sell inter " + self + " " + exchange;
							}
						}
					}
				}
			}
			my_inter.stock <- stock;
	}
	
	action sell1{ //sell du maximum (en qantité) au plus proche
		list<Intermediary> temp <- (Intermediary where not(each.is_Producer));
		temp <- temp sort_by(each distance_to self); //On peut mettre des expressions dans le sort_by.
		loop tempInt over: temp{
				if(stock>0){
						if(tempInt.stock<tempInt.capacity and /*myself.*/stock>0){
						int exchange <- min(tempInt.capacity-tempInt.stock,/*myself.*/stock);
						if(exchange >0){
							ask tempInt{
								stock <- stock + exchange;
							}
							/*myself.*/stock <- /*myself.*/stock-exchange;
								if(tempInt.is_Consumer){
									write "sell consu " + tempInt + " " + exchange;
									//on crée une Ware avec les bonnes données.
									create Ware number: 1{
										prodPlace <- myself;
										origin <- myself.my_inter;
										quantity <- exchange;
										target <- tempInt.my_consum.location;
										distance <- myself distance_to tempInt.my_consum;
									}
								} else {
									write "sell inter " + tempInt + " " + exchange;
									create Ware number: 1{
										prodPlace <- myself;
										quantity <- exchange;
										target <- tempInt.location;
										distance <- myself distance_to tempInt;
									}
								}
							}
						}
				}
			}
			my_inter.stock <- stock;
	}
	
	action sell2{ //sell au plus loin
		list<Intermediary> temp <- (Intermediary where not(each.is_Producer));
		temp <- temp sort_by(1/each distance_to self); //On peut mettre des expressions dans le sort_by.
		loop tempInt over: temp{
				if(stock>0){
					ask tempInt{
						if(stock<capacity and myself.stock>0){
						int exchange <- min(capacity-stock,myself.stock);
						stock <- stock + exchange;
						myself.stock <- myself.stock-exchange;
							if(self.is_Consumer){
								write "sell consum " + self + " " + exchange;
							} else {
								write "sell inter " + self + " " + exchange;
							}
						}
					}
				}
			}
			my_inter.stock <- stock;
	}
	
	aspect base {
		if (stock>0){
			draw triangle(stock) color:#red;
		}else {
			draw triangle(1) color:#red;
		}
	}
}

species Ware{ 
	int type;
	int quantity;
	Intermediary origin; //last intermediary before buy
	Producer prodPlace; //the place where the ware was produced
	point target <- nil; 
	float distance;
	
	reflex move when: target!=nil{
		location <- target;
		target <- nil;
	}
	
	aspect base {
		
	}
}

species PolygonWare { //Used to draw the polygon of wares depending on their place of production
	Producer placeProd;
	geometry shape;
	rgb color;
	
	init{
		color<-rgb(rnd(255),rnd(255),rnd(255));
	}
	
	aspect base {
		draw shape color: color ;
	}
}

experiment Spreading type: gui {

	
	// Define parameters here if necessary
	// parameter "My parameter" category: "My parameters" var: one_global_attribute;
	
	// Define attributes, actions, a init section and behaviors if necessary
	// init { }
	
	
	output {
	// Define inspectors, browsers and displays here
	
	// inspect one_or_several_agents;
	//
		display main_display background: #lightgray { 
			species Consumer aspect:base;
			species Intermediary aspect:base;
			species Producer aspect:base;
			species Ware;
			species PolygonWare transparency: 0.5;
		}
		
		display chart /*refresh:every(10.0)*/  {
			chart "distance of wares" type: series {
				data "average distance" value: averageDistance color: #green;
				data "distance max" value: distanceMax color: #red;
				data "distance min" value:distanceMin color: #blue;
			}
		}
	
	}
}