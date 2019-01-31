/***
* Name: StoneModel
* Author: mathieu
* Description: Adaptaton du m�ta-mod�le de diffusion des arch�o-mat�riaux au cas particulier de la craie pour les constructions
* Tags: Tag1, Tag2, TagN
***/

model StoneModel


global schedules: shuffle(Consommateur) + shuffle(Intermediaire) + shuffle(Marchandise) + shuffle(Producteur) {
	int nb_init_consommateur <- 2 parameter: true;
	int nb_init_intermediaire <- 1 parameter: true; //correspond aux intermédiaires hors producteur et consommateur
	int nb_init_prod <- 2 parameter: true;
	geometry shape <- square(200/*0*/);
	float averageDistance <- 0.0;
	float distanceMax <- 0.0;
	float distanceMin <- 0.0;
	int prodTaux <- 5 parameter:true;
	int prodTauxFixe <- 50 parameter:true;
	int consumTaux <- 50 parameter:true;
	int consumTauxFixe <- 500 parameter:true;
	int capaciteInter <- 30 parameter: true;
	int stock_max_prod <- 10 parameter: true;
	int stock_max_prod_fixe <- 100 parameter: true;
	
	int consumer_strategy <- 1 parameter: true min: 1 max: 2; //1:buy to producers and intermediaries. 2:only buy to inermediairies.
	int intermediary_strategy <- 1 parameter: true min:1 max: 3; //1: buy the stock. 2: buy stock and place orders. 3: only place orders.
	int producer_strategy <- 1 parameter: true min: 1 max: 2; //1: produce just what has been oredered. 2: produce the maximum it can
	
	init {
		do createConso(nb_init_consommateur);
		do createProd(nb_init_prod);
		do createInter(nb_init_intermediaire);
	}
	
	user_command "create conso"{ //à activer avec clic-droit->world->actions
		do createConso(1);
	}
	
	user_command "destroy conso"{
		do destroyConso;
	}
	
	user_command "create prod"{ //à activer avec clic-droit->world->actions
		do createProd(1);
	}
	
	user_command "destroy prod"{
		do destroyProd;
	}
	
	user_command "create inter"{ //à activer avec clic-droit->world->actions
		do createInter(1);
	}
	
	user_command "destroy inter"{
		do destroyInter;
	}
	
	action createConso(int nb_conso){
		create Consommateur number: nb_conso{
			create Intermediaire number: 1{
				location <-myself.location;
				est_consommateur <- true;
				mon_conso <- myself;
				est_producteur <- false;
				mon_prod <- nil;
				capacite <- myself.besoin;
				stock <- myself.recupere;
				argent <- myself.argent;
				
				ask myself{
					mon_inter <- myself;
				}
			}
		}
	}
	
	action destroyConso{
		ask one_of(Consommateur){
			do die ;
		}
	}
	
	action createProd(int nb_prod){
		create Producteur number: nb_prod{
			create Intermediaire number: 1{
				location <-myself.location;
				est_consommateur <- false;
				mon_conso <- nil;
				est_producteur <- true;
				mon_prod <- myself;
				capacite <- myself.stockMax;
				stock <- myself.stock;
				
				ask myself{
					mon_inter <- myself;
				}
			}
		}
	}
	
	action destroyProd{
		ask one_of(Producteur){
			do die ;
		}
	}
	
	action createInter(int nb_inter){
		create Intermediaire number: nb_inter{
			est_producteur <- false;
			mon_prod <- nil;
			est_consommateur <- false;
			mon_conso <- nil;
			capacite <- rnd(capaciteInter);
		}
	}
	
	action destroyInter{
		ask one_of(Intermediaire where ((not(each.est_producteur)) and (not(each.est_consommateur)))){
			do die ;
		}
	}
	
	//TODO : faire la même chose mais pour chaque intermédiaire
	reflex affichage {
		write "-------------------------";
		averageDistance <- 0.0;
		if(not empty(Marchandise)){
			distanceMax <- first(Marchandise).distance;
			distanceMin <- first(Marchandise).distance;
		}
		loop temp over: Marchandise{
			averageDistance<- averageDistance + temp.distance;
			if(temp.distance>distanceMax){
				distanceMax <- temp.distance;
			}
			if(temp.distance<distanceMin){
				distanceMin <- temp.distance;
			}
		}
		if(not empty(Marchandise)){
			averageDistance <- averageDistance/length(Marchandise);
		}
		if(not(empty(Marchandise))){
			loop tempProd over: Producteur{
				bool exists <- false;
				loop tempPoly over: PolygonWare{
					if tempPoly.placeProd = tempProd {
						exists <- true;
					}
				}
				if(exists){
					PolygonWare polyChange <- PolygonWare first_with (each.placeProd=tempProd);
					list<Marchandise> tempWares <- Marchandise where (each.lieuProd = tempProd);
					if not empty(tempWares){
						list<Marchandise> wareKept;
						add first(tempWares) to: wareKept;
						list<Intermediaire> placeVisited;
						add first(Intermediaire where(first(wareKept).location = each.location)) to: placeVisited;
						loop tempWare over: tempWares{
							Intermediaire placeWare <- first(Intermediaire where(tempWare.location = each.location));
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
					list<Marchandise> tempWares <- Marchandise where (each.lieuProd = tempProd);
					shape <- /*convex_hull(*/polygon(tempWares)/*)*/;
					}
				}
			}
		}
	}
	
	reflex stop{
		bool isFinished <- true;
		loop tempConso over: Consommateur{
			if not (tempConso.est_construit){
				isFinished <- false;
			}
		}
		if isFinished {
			int builtTimeMax<-first(Consommateur).time_to_be_built;
			int builtTimeMin<-first(Consommateur).time_to_be_built;
			float builtTimeAverage<-0.0;
			loop tempConso over:Consommateur{
				if tempConso.time_to_be_built > builtTimeMax {
					builtTimeMax <- tempConso.time_to_be_built;
				}
				if tempConso.time_to_be_built < builtTimeMax {
					builtTimeMin <- tempConso.time_to_be_built;
				}
				builtTimeAverage <- builtTimeAverage + tempConso.time_to_be_built;
			}
			write "Max time : " + builtTimeMax;
			write "Average time : " + builtTimeAverage/length(Consommateur);
			write "Min time : " + builtTimeMin;
			do pause;
		}
	}
	
}

species Consommateur {
	//TODO //diversifier en fonction des types et ajouter la variable d'argent.
	int argent;
	int besoin <- consumTauxFixe + rnd(consumTaux) ;//update:consumTauxFixe + rnd(consumTaux) ; //dans le cade de la craie, le besoin serait fixe et représenterait le besoin total de la construction 
	int recupere <- 0 ;
	Intermediaire mon_inter; 
	
	bool est_construit<-false;
	int time_to_be_built <- 0;
	
	reflex updateInterStart{
		mon_inter.capacite <- besoin;
		mon_inter.stock <- recupere;
	}
	
	reflex updateConstruit when:not est_construit{
		if(recupere>=besoin){
			est_construit <- true;
			write self.name + " est construit";
		}
		time_to_be_built <- time_to_be_built +1;
	}
	
	//TODO ajouter l'argent dans le calcul
	reflex acheter when: not est_construit{
		if(consumer_strategy=1){
			do achat1;
		}
		if(consumer_strategy=2){
			do achat2;
		}
	}
	
	action achat1 {
		list<Intermediaire> temp <- Intermediaire where (not(each.est_consommateur));
		temp <- temp sort_by(each distance_to self);
		loop tempInt over: temp{
			if (recupere<besoin){
				int recupTemp;
				if(tempInt.est_producteur){
				recupTemp <- min(besoin,tempInt.mon_prod.stockMax-tempInt.mon_prod.production);
				recupere <- recupere+recupTemp;
				if(recupTemp>0){
						write "achat prod " + recupTemp;
						create Marchandise number: 1{
							lieuProd <- tempInt.mon_prod;
							provenance <- tempInt;
							quantity <- recupTemp;
							target <- myself.location;
							distance <- myself distance_to tempInt.mon_prod;
						}
						//tempInt.stock <- tempInt.stock - recupTemp;
						tempInt.mon_prod.production <- tempInt.mon_prod.production + recupTemp;
					}
				} else {
					if(recupTemp>0){
						write "achat inter " + recupTemp;
						list<Marchandise> tempWares <- Marchandise where(each.location = tempInt.location);
						bool endCollecting <- false;
						int recupWare<-0;
						loop tempLoop over: tempWares{
							if(not endCollecting){
								if (recupWare+tempLoop.quantity <= recupTemp) {
									recupWare <- recupWare + tempLoop.quantity;
									tempLoop.target <- self.location;
									tempLoop.distance <- tempLoop.distance + tempLoop distance_to self;
								} else {
									create Marchandise number: 1{
										quantity <- recupTemp-recupWare;
										target <- myself.location;
										distance <- tempLoop.distance + self distance_to myself;
										provenance <- tempLoop.provenance;
										lieuProd <- tempLoop.lieuProd;
									}
									tempLoop.quantity <- tempLoop.quantity - (recupTemp-recupWare);
									recupWare <- recupTemp;
								}
								if(recupWare >= recupTemp){
									endCollecting <- true;
								}
							}
						}
					}
					ask tempInt{
						stock <- stock - recupTemp;
					}	
				}
			}
		}
		mon_inter.capacite <- besoin;
		mon_inter.stock <- recupere;
	}
	
	action achat2{
		list<Intermediaire> temp <- Intermediaire where (not(each.est_consommateur));
		temp <- temp sort_by(each distance_to self);
		loop tempInt over: temp{
			if (recupere<besoin){
				int recupTemp;
				if (not(tempInt.est_producteur)and not(tempInt.est_consommateur)){
				recupTemp <- min(besoin,tempInt.stock);
				recupere <- recupere+recupTemp;
				if(recupTemp>0){
						write "achat inter " + recupTemp;
						list<Marchandise> tempWares <- Marchandise where(each.location = tempInt.location);
						bool endCollecting <- false;
						int recupWare<-0;
						loop tempLoop over: tempWares{
							if(not endCollecting){
								if (recupWare+tempLoop.quantity <= recupTemp) {
									recupWare <- recupWare + tempLoop.quantity;
									tempLoop.target <- self.location;
									tempLoop.distance <- tempLoop.distance + tempLoop distance_to self;
								} else {
									create Marchandise number: 1{
										quantity <- recupTemp-recupWare;
										target <- myself.location;
										distance <- tempLoop.distance + self distance_to myself;
										provenance <- tempLoop.provenance;
										lieuProd <- tempLoop.lieuProd;
									}
									tempLoop.quantity <- tempLoop.quantity - (recupTemp-recupWare);
									recupWare <- recupTemp;
								}
								if(recupWare >= recupTemp){
									endCollecting <- true;
								}
							}
						}
					}
					ask tempInt{
						stock <- stock - recupTemp;
					}	
				}
			}
		}
		mon_inter.capacite <- besoin;
		mon_inter.stock <- recupere;
	}
	
	aspect base {
		draw square(10) color:#blue;
	}
}

//Dans un premier temps, chaque intermédiaire est spécialisé dans un seul type, sauf les consommateurs qui auront les deux types (commun et supérieurs)
species Intermediaire {
	//un disque dont la taille varie en fonction du stock
	int stock <- 0;
	int capacite <- rnd(capaciteInter); //capacite d'achat auprès des producteurs
	int prix <- 0; //représente la pénalité ajoutée par l'intermédiaire.
	bool est_producteur; //représente la partie commerciale d'un producteur
	Producteur mon_prod;
	bool est_consommateur; //représente la partie commeriale d'un consommateur
	Consommateur mon_conso;
	int argent;
	
	reflex buy {
		if intermediary_strategy=1 {
			do achat1;
		}
		if intermediary_strategy=2{
			do achat2;
		}
		if intermediary_strategy=3{
			do achat3;
		}
	}
	
	action achat1 { //achat comme un conso
		int recupere <- 0;
		list<Intermediaire> temp <- Intermediaire where (not(each.est_consommateur));
		temp <- temp sort_by(each distance_to self);
		loop tempInt over: temp{
			if (stock<capacite){
				int recupTemp;
				if(tempInt.est_producteur){
				recupTemp <- min(capacite,tempInt.stock);
				recupere <- recupere+recupTemp;
				if(recupTemp>0){
						write "achat prod " + recupTemp;
						create Marchandise number: 1{
							lieuProd <- tempInt.mon_prod;
							provenance <- tempInt;
							quantity <- recupTemp;
							target <- myself.location;
							distance <- myself distance_to tempInt.mon_prod;
						}
						tempInt.stock <- tempInt.stock - recupTemp;
						//tempInt.mon_prod.production <- tempInt.mon_prod.production + recupTemp;
					}
				}
			}
		}
		stock <- recupere;
	}
	
	action achat2 { //achat comme un conso + stock
		int recupere <- 0;
		list<Intermediaire> temp <- Intermediaire where (not(each.est_consommateur));
		temp <- temp sort_by(each distance_to self);
		loop tempInt over: temp{
			if (stock<capacite){
				int recupTemp;
				if(tempInt.est_producteur){
				recupTemp <- min(capacite,tempInt.stock); //on achête en priorité le stock
				recupere <- recupere+recupTemp;
				stock <- recupere;
				}
				if(recupTemp>0){
						write "achat prod " + recupTemp;
						create Marchandise number: 1{
							lieuProd <- tempInt.mon_prod;
							provenance <- tempInt;
							quantity <- recupTemp;
							target <- myself.location;
							distance <- myself distance_to tempInt.mon_prod;
						}
						tempInt.stock <- tempInt.stock - recupTemp;
						//tempInt.mon_prod.production <- tempInt.mon_prod.production + recupTemp;
					}
				if (stock<capacite){
				recupTemp <- min(capacite,tempInt.mon_prod.stockMax-tempInt.mon_prod.production);
				recupere <- recupere+recupTemp;
				if(recupTemp>0){
						write "achat prod " + recupTemp;
						create Marchandise number: 1{
							lieuProd <- tempInt.mon_prod;
							provenance <- tempInt;
							quantity <- recupTemp;
							target <- myself.location;
							distance <- myself distance_to tempInt.mon_prod;
						}
						//tempInt.stock <- tempInt.stock - recupTemp;
						tempInt.mon_prod.production <- tempInt.mon_prod.production + recupTemp;
					}
				}
				stock <- recupere;
			}
		}
	}
	
	action achat3 { //achat comme un conso
		int recupere <- 0;
		list<Intermediaire> temp <- Intermediaire where (not(each.est_consommateur));
		temp <- temp sort_by(each distance_to self);
		loop tempInt over: temp{
			if (stock<capacite){
				int recupTemp;
				if(tempInt.est_producteur){
				recupTemp <- min(capacite,tempInt.mon_prod.stockMax-tempInt.mon_prod.production);
				recupere <- recupere+recupTemp;
				if(recupTemp>0){
						write "achat prod " + recupTemp;
						create Marchandise number: 1{
							lieuProd <- tempInt.mon_prod;
							provenance <- tempInt;
							quantity <- recupTemp;
							target <- myself.location;
							distance <- myself distance_to tempInt.mon_prod;
						}
						//tempInt.stock <- tempInt.stock - recupTemp;
						tempInt.mon_prod.production <- tempInt.mon_prod.production + recupTemp;
					}
				}
			}
		}
		stock <- recupere;
	}
	
	aspect base {
		if(not(est_producteur) and not(est_consommateur)){
			if (stock>0){
				draw circle(stock) color:#green;
			} else {
				draw circle(1) color:#green;
			}	
		}
	}
}

species Producteur{
	int production <- 0 ;//représente le nombre de marchandise produite en 1 cycle
	int productionBefore;
	int stock <- 0 ;
	int stockMax <- stock_max_prod_fixe ;//+ rnd(stock_max_prod);
	Intermediaire mon_inter;
	
	reflex produit {
		if producer_strategy=1{
			productionBefore <- production;
			production <- 0;
			stock <- 0;
		}
		if producer_strategy=2{
			productionBefore <- production;
			production <- 0;
			stock <- stockMax-productionBefore;
		}
	}
	
	reflex updateInter{
		//Ici, le stock de l'itermédiaire représente le surplus produit au cycle précédent
		mon_inter.stock<-stock;
	}
	
	aspect base {
			draw triangle(10) color:#red;
	}
}

//TODO : créer des entitées marchandises qui seront réellements échangées entre les intermédiaires. Cela permettrait aussi le traçage des marchandises (pour la sortie)
species Marchandise{ //Ware en anglais (ou commodity)
	int type;
	int quantity;
	Intermediaire provenance; //le dernier inter avant achat
	Producteur lieuProd; //l'endroit où la marchandise a été produite
	point target <- nil; //le lieu de destination pour le déplacement.
	float distance; //représente la distance parcouru par la marchandise.
	
	reflex move when: target!=nil{
		location <- target;
		target <- nil;
	}
	
	aspect base {
		
	}
}

species PolygonWare { //Used to draw the polygon of wares depending on their place of production
	Producteur placeProd;
	geometry shape;
	rgb color;
	
	init{
		color<-rgb(rnd(255),rnd(255),rnd(255));
	}
	
	aspect base {
		draw shape color: color ;
	}
}

experiment Propagation type: gui {

	
	// Define parameters here if necessary
	// parameter "My parameter" category: "My parameters" var: one_global_attribute;
	
	// Define attributes, actions, a init section and behaviors if necessary
	// init { }
	
	
	output {
	// Define inspectors, browsers and displays here
	
	// inspect one_or_several_agents;
	//
		display affichagePrincipal background: #lightgray { 
			species Consommateur aspect:base;
			species Intermediaire aspect:base;
			species Producteur aspect:base;
			species Marchandise;
			species PolygonWare transparency: 0.5;
		}

		display chart /*refresh:every(10.0)*/  {
			chart "distance of wares" type: series {
				data "average distance" value: averageDistance color: #green;
				data "distance max" value: distanceMax color: #red;
				data "distance min" value:distanceMin color: #blue;
			}
		}
	
		display "production information" {
			chart "production information" type:histogram
			{
				loop tempProd over: Producteur {
					data tempProd.name value: tempProd.productionBefore;
				}
			}
		} 
	
	}
}

