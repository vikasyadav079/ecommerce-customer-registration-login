package org.example.architecture;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.repository.Repository;
import org.springframework.stereotype.Service;
import org.springframework.web.bind.annotation.RestController;

import jakarta.persistence.Entity;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;

@AnalyzeClasses(packages = "org.example", importOptions = ImportOption.DoNotIncludeTests.class)
public class CodingConventionTest {

    @ArchTest
    static final ArchRule controllers_should_reside_in_controller_package =
            classes().that().areAnnotatedWith(RestController.class)
                    .should().resideInAPackage("..controller..");

    @ArchTest
    static final ArchRule services_should_reside_in_service_package =
            classes().that().areAnnotatedWith(Service.class)
                    .should().resideInAPackage("..service..");

    @ArchTest
    static final ArchRule entities_should_reside_in_entity_package =
            classes().that().areAnnotatedWith(Entity.class)
                    .should().resideInAPackage("..entity..");

    @ArchTest
    static final ArchRule repositories_should_be_interfaces =
            classes().that().areAssignableTo(Repository.class)
                    .should().beInterfaces();
}
