/***
* Name: MetaModel
* Author: mathieu
* Description: un mod�le g�n�rale de la diffusion des arch�oma�riaux dans le cadre du projet RIN ATP
* Tags: Tag1, Tag2, TagN
***/

model MetaModel

global schedules: shuffle(Consommateur) + shuffle(Intermediaire) + shuffle(Marchandise) + shuffle(Producteur){
	int nb_init_consommateur <- 2 parameter: true;
	int nb_init_intermediaire <- 1 parameter: true; //correspond aux intermédiaires hors producteur et consommateur
	int nb_init_prod <- 2 parameter: true;
	geometry shape <- square(200/*0*/);
	float averageDistance <- 0.0;
	float distanceMax <- 0.0;
	float distanceMin <- 0.0;
	int prodTaux <- 5 parameter:true;
	int prodTauxFixe <- 50 parameter:true;
	int consumTaux <- 5 parameter:true;
	int consumTauxFixe <- 50 parameter:true;
	int capaciteInter <- 30 parameter: true;
	int stock_max_prod <- 10 parameter: true;
	int stock_max_prod_fixe <- 100 parameter: true;
	
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
			//pour chaque consommateur, on lui crée un intermédiaire qui sera sa partie commerciale
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
			//pour chaque producteur, on lui crée un intermédiaire qui sera sa partie commerciale
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
	
	//TODO : faire la même chose mais pour chaque intermédiaire ?
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
	
}

species Consommateur {
	//TODO //diversifier en fonction des types et ajouter la variable d'argent.
	int argent;
	int besoin <- consumTauxFixe + rnd(consumTaux) update:consumTauxFixe + rnd(consumTaux) ; //dans le cade de la craie, le besoin serait fixe et représenterait le besoin total de la construction 
	int recupere <- 0 update: 0; //dans le cade de la craie, les matières récupérées ne seraient pas remise à zéro à chaque tour (cette remise à zéro symbolise la consommation)
	Intermediaire mon_inter; 
	
	bool est_construit; //utilisé sur les bâtiments pour montrer que le batiment n'a plus besoin de pierre.
	
	reflex updateInterStart{
		mon_inter.capacite <- besoin;
		mon_inter.stock <- recupere;
	}
	
	//TODO ajouter l'argent dans le calcul
	reflex acheter { //on achète à tous les intermédiaires qui ne sont pas des consommateurs
//		do achat0;
		do achat1; //à remplacer en fonction de la méthode que l'on veut tester
//		do achat2;
	}
	
	action achat0{
		//choix aléatoire, quelques soit la distance, etc (utiliser le shuffle). Utilisé comm comparateur de base.
		loop tempInt over: shuffle(Intermediaire where (not(each.est_consommateur))){
			if (recupere<besoin){
				int recupTemp;
				recupTemp <- min(besoin,tempInt.stock);
				recupere <- recupere+recupTemp;
				if(tempInt.est_producteur){
					write "achat prod " + recupTemp;
				} else {
					write "achat inter " + recupTemp;
				}
				ask tempInt{
					stock <- stock - recupTemp;
				}
			}
		}
		mon_inter.capacite <- besoin;
		mon_inter.stock <- recupere;
	}
	
	action achat1 { //Achat du maximum (en quantité) en fonction de la distance, sans pénalité rajoutée par les intermédiaires.
		list<Intermediaire> temp <- Intermediaire where (not(each.est_consommateur));
		temp <- temp sort_by(each distance_to self); //Le distance_to s'applique sur la topologie de l'agent appelant (chaque espèce possède une topology comme built-in attribute sur laquelle il évolue)
		loop tempInt over: temp{
			if (recupere<besoin){
				int recupTemp;
				recupTemp <- min(besoin,tempInt.stock);
				recupere <- recupere+recupTemp;
				if(recupTemp>0){
					if(tempInt.est_producteur){
						write "achat prod " + recupTemp;
						create Marchandise number: 1{
							lieuProd <- tempInt.mon_prod;
							provenance <- tempInt;
							quantity <- recupTemp;
							target <- myself.location;
							distance <- myself distance_to tempInt.mon_prod;
						}
					} else {
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
	
	//TODO : préparer l'ajout d'un prix ou le calcul d'une autre distance (ou les deux)
	action achat2{ // Achat au plus loin
		list<Intermediaire> temp <- Intermediaire where (not(each.est_consommateur));
		temp <- temp sort_by(1/each distance_to self); //On peut mettre des expressions dans le sort_by.
		loop tempInt over: temp{
			if (recupere<besoin){
				int recupTemp;
				recupTemp <- min(besoin,tempInt.stock);
				recupere <- recupere+recupTemp;
				if(tempInt.est_producteur){
					write "achat prod " + recupTemp;
				} else {
					write "achat inter " + recupTemp;
				}
				ask tempInt{
					stock <- stock - recupTemp;
				}
			}
		}
		mon_inter.capacite <- besoin;
		mon_inter.stock <- recupere;
	}
	
	//un carré de couleur dont la taille peut varier en foction d'un paramètre (le besoin, l'argent, etc ?)
	aspect base {
		draw square(10) color:#blue;
	}
}

//Dans un premier temps, chaque intermédiaire est spécialisé dans un seul type, sauf les consommateurs qui auront les deux types (commun et supérieurs)
species Intermediaire {//intermediary en anglais
	//un disque dont la taille varie en fonction du stock
	int stock <- 0;
	int capacite <- rnd(capaciteInter); //capacite d'achat auprès des producteurs
	int prix <- 0; //représente la pénalité ajoutée par l'intermédiaire.
	bool est_producteur; //représente la partie commerciale d'un producteur
	Producteur mon_prod;
	bool est_consommateur; //représente la partie commeriale d'un consommateur
	Consommateur mon_conso;
	int argent;
	
	//TODO : ajouter la capacité d'achat des intermédiaires, dans un cas de figure.
	
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
	int production <- prodTauxFixe + rnd(prodTaux) update:prodTauxFixe + rnd(prodTaux) ;//représente le nombre de marchandise produite en 1 cycle
	int stock <- 0 ;
	int stockMax <- stock_max_prod_fixe + rnd(stock_max_prod);
	Intermediaire mon_inter;
	
	reflex produit when: stock/*+production*/<stockMax{
		stock <- stock+production;
	}
	
	reflex updateInter{
		mon_inter.stock<-stock;
	}
	
	reflex vendre { //on vend à tous les intermédiaires qui ne sont pas des producteurs
		if(mon_inter.stock>0){
//			do vente0;
			do vente1;
//			do vente2;
		}
	}
	
	action vente0{
		//choix aléatoire, quelques soit la distance, etc (utiliser le shuffle). Utilisé comm comparateur de base.
		loop tempInt over: shuffle(Intermediaire where not(each.est_producteur)){
				if(stock>0){
					ask tempInt{
						if(stock<capacite and myself.stock>0){
						int echange <- min(capacite-stock,myself.stock);
						stock <- stock + echange;
						myself.stock <- myself.stock-echange;
							if(self.est_consommateur){
								write "vente conso " + self + " " + echange;
							} else {
								write "vente inter " + self + " " + echange;
							}
						}
					}
				}
			}
			mon_inter.stock <- stock;
	}
	
	action vente1{ //vente du maximum (en qantité) au plus proche
		list<Intermediaire> temp <- (Intermediaire where not(each.est_producteur));
		temp <- temp sort_by(each distance_to self); //On peut mettre des expressions dans le sort_by.
		loop tempInt over: temp{
				if(stock>0){
						if(tempInt.stock<tempInt.capacite and /*myself.*/stock>0){
						int echange <- min(tempInt.capacite-tempInt.stock,/*myself.*/stock);
						if(echange >0){
							ask tempInt{
								stock <- stock + echange;
							}
							/*myself.*/stock <- /*myself.*/stock-echange;
								if(tempInt.est_consommateur){
									write "vente conso " + tempInt + " " + echange;
									//on crée une marchandise avec les bonnes données.
									create Marchandise number: 1{
										lieuProd <- myself;
										provenance <- myself.mon_inter;
										quantity <- echange;
										target <- tempInt.mon_conso.location;
										distance <- myself distance_to tempInt.mon_conso;
									}
								} else {
									write "vente inter " + tempInt + " " + echange;
									create Marchandise number: 1{
										lieuProd <- myself;
										quantity <- echange;
										target <- tempInt.location;
										distance <- myself distance_to tempInt;
									}
								}
							}
						}
				}
			}
			mon_inter.stock <- stock;
	}
	
	action vente2{ //Vente au plus loin
		list<Intermediaire> temp <- (Intermediaire where not(each.est_producteur));
		temp <- temp sort_by(1/each distance_to self); //On peut mettre des expressions dans le sort_by.
		loop tempInt over: temp{
				if(stock>0){
					ask tempInt{
						if(stock<capacite and myself.stock>0){
						int echange <- min(capacite-stock,myself.stock);
						stock <- stock + echange;
						myself.stock <- myself.stock-echange;
							if(self.est_consommateur){
								write "vente conso " + self + " " + echange;
							} else {
								write "vente inter " + self + " " + echange;
							}
						}
					}
				}
			}
			mon_inter.stock <- stock;
	}
	
	//un triangle dont la taille va dépenre du stock
	aspect base {
		if (stock>0){
			draw triangle(stock) color:#red;
		}else {
			draw triangle(1) color:#red;
		}
	}
}

//TODO : créer des entitées marchandises qui seront réellements échangées entre les intermédiaires. Cela permettrait aussi le traçage des marchandises (pour la sortie)
//TODO : les marchandisent se déplaceront jusqu'à arriver à un consommateur. Ensuite, elles resteront là où elles sont, pour les comptes à la fin.
//TODO : Dans un premier temps, le déplacement peut être instantané (location <- target.location), on mettra un moving skill après (avec calcul du plus court chemin, etc)

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
		//TODO : afficher la proportion de marchandises en fonction de leur lieu de prod/dernier inter par lieu de consommation.
		//TODO : afficher un temps d'attente pour être servi.
		display chart /*refresh:every(10.0)*/  {
			chart "distance of wares" type: series {
				data "average distance" value: averageDistance color: #green;
				data "distance max" value: distanceMax color: #red;
				data "distance min" value:distanceMin color: #blue;
			}
		}
	
	}
}