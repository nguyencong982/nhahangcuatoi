buildscript {
    // Để khai báo biến trong Kotlin DSL, bạn dùng `val`
    val kotlin_version by extra("1.9.0") // Hoặc phiên bản Kotlin hiện tại của bạn

    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Trong Kotlin DSL, bạn dùng `classpath()` thay vì `classpath ` (có dấu ngoặc đơn)
        classpath("com.android.tools.build:gradle:8.3.0") // Hoặc phiên bản Gradle Plugin hiện tại của bạn
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
        // THÊM DÒNG NÀY ĐỂ KẾT NỐI VỚI GOOGLE SERVICES (Firebase)
        classpath("com.google.gms:google-services:4.4.1") // Đảm bảo đây là phiên bản mới nhất
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Cú pháp khai báo biến trong Kotlin DSL:
val newBuildDir: org.gradle.api.file.Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir) // Sử dụng .set() thay vì .value()

subprojects {
    val newSubprojectBuildDir: org.gradle.api.file.Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir) // Sử dụng .set() thay vì .value()
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Cú pháp cho task `clean` trong Kotlin DSL
tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}