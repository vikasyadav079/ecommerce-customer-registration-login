package org.example.architecture;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

import static com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

@AnalyzeClasses(packages = "org.example", importOptions = ImportOption.DoNotIncludeTests.class)
public class PackageBoundaryTest {

    @ArchTest
    static final ArchRule identity_should_not_depend_on_other_contexts =
            noClasses().that().resideInAPackage("..identity..")
                    .should().dependOnClassesThat().resideInAnyPackage(
                            "..profile..", "..notification..", "..audit..");

    @ArchTest
    static final ArchRule profile_should_not_depend_on_other_contexts =
            noClasses().that().resideInAPackage("..profile..")
                    .should().dependOnClassesThat().resideInAnyPackage(
                            "..identity..", "..notification..", "..audit..");

    @ArchTest
    static final ArchRule notification_should_not_depend_on_other_contexts =
            noClasses().that().resideInAPackage("..notification..")
                    .should().dependOnClassesThat().resideInAnyPackage(
                            "..identity..", "..profile..", "..audit..");

    @ArchTest
    static final ArchRule audit_should_not_depend_on_other_contexts =
            noClasses().that().resideInAPackage("..audit..")
                    .should().dependOnClassesThat().resideInAnyPackage(
                            "..identity..", "..profile..", "..notification..");

    @ArchTest
    static final ArchRule shared_should_not_depend_on_contexts =
            noClasses().that().resideInAPackage("..shared..")
                    .should().dependOnClassesThat().resideInAnyPackage(
                            "..identity..", "..profile..", "..notification..", "..audit..");

    @ArchTest
    static final ArchRule controllers_should_not_access_repositories =
            noClasses().that().resideInAPackage("..controller..")
                    .should().dependOnClassesThat().resideInAPackage("..repository..");

    @ArchTest
    static final ArchRule no_cycles_between_slices =
            slices().matching("org.example.(*)..").should().beFreeOfCycles();
}
