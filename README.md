# coeval
Self-assessment and Peer-assessment Software for educational settings

<img src="http://coeval.org/public/logo.svg" width="225" alt="Coeval Logo" />

Web based platform to manage Self-assessment and Peer-assessment for teamwork. Developed using Sinatra, a Ruby-based DSL.

**Note**: This software is untested. Use at your own risk!
**Note 2**: This software relies on the same logic of [Buhos](https://github.com/clbustos/buhos). 

## Features

* Multi-platform:  Runs on any ruby based platform.
* Internal messaging system for personal messages.
* Allows multiple institutions, courses, asssessments and criteria.
* Internationalization, using *I18n*. Available in English and Spanish.


**NOTE**: This is a very initial version, but fully operational. If you are interested, you could send a message to
coeval@investigarenpsicologia.cl for a demo.

## Installation

You could use sqlite (not tested), or MySQL / MariaDB. Create a user, a database
and provide access to the user

    CREATE DATABASE coeval;
    CREATE USER coeval_user@localhost IDENTIFIED BY 'password';
    GRANT ALL PRIVILEGES ON coeval.* TO coeval_user@localhost;
    FLUSH PRIVILEGES;

Create a **.env** file with the following information

    DATABASE_URL=mysql2://coeval_user:password@localhost:3306/coeval
    SMTP_SERVER=YOUR_SMTP_SERVER
    SMTP_USER=YOUR_SMTP_USER
    SMTP_PASSWORD=YOUR_SMTP_PASSWORD
    SMTP_SECURITY=STARTTLS 
    SMTP_PORT=YOUR_SMTP_PORT


Create database with

    ruby crear_database.rb

**THE FOLLOWING IS A VERY RAW METHOD. MY EXCUSES**

Create three excel (.xlsx) files

* criterios.xlsx . Provide criteria for assessments. Use *criterio_id* 
  for criterion_id,  *criterion_name* for criterion name and criterion_type 
  (ordered_levels or open_ended)
* niveles.xlsx. Provide levels for each criteria. Each row is a level for a criterion.
  Use *criterio_id* from previous excel, *points* for points to give and *description*
  for the description of the level
* curso_grupos_1.xlsx. Provide students. Use *email* for student's email, *name* for student's name,
  'matricula' for enrolement number

Use 

    ruby cargar_datos.rb

To fill the database with minimum information to work.
The admin user have password 'admin' by default. You should change as soon as possible.


## Built With
* [Sinatra](http://sinatrarb.com/) - Sinatra is a DSL for quickly creating web applications on Ruby with minimal effort.
* [Sequel](https://github.com/jeremyevans/sequel) - Sequel is a simple, flexible, and powerful SQL database access toolkit for Ruby. It offers an abstraction layer and ORM functionalities, among other things.
* [Bootstrap](https://getbootstrap.com/) -  Bootstrap is an open source toolkit for developing with HTML, CSS, and JS.
* [RubyMine](https://www.jetbrains.com/ruby/) - An excellent Ruby IDE
